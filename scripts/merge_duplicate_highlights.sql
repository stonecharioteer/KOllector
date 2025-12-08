-- Merge duplicate highlights that differ only by page number
-- Strategy:
-- 1. For each group of duplicates (same book_id, text, kind):
--    - Keep the first highlight (lowest ID)
--    - Merge device associations from duplicates into the kept highlight
--    - Delete the duplicate highlights

-- Create a temp table with duplicate groups
CREATE TEMP TABLE duplicate_groups AS
SELECT
    book_id,
    text,
    kind,
    MIN(id) as keep_id,
    array_agg(id ORDER BY id) as all_ids,
    COUNT(*) as dup_count
FROM highlights
WHERE text <> ''
GROUP BY book_id, text, kind
HAVING COUNT(*) > 1;

-- Merge device associations from duplicates to the kept highlight
INSERT INTO highlight_devices (highlight_id, device_id)
SELECT DISTINCT
    dg.keep_id,
    hd.device_id
FROM duplicate_groups dg
CROSS JOIN UNNEST(dg.all_ids) as dup_id
JOIN highlight_devices hd ON hd.highlight_id = dup_id
WHERE NOT EXISTS (
    SELECT 1 FROM highlight_devices hd2
    WHERE hd2.highlight_id = dg.keep_id
    AND hd2.device_id = hd.device_id
);

-- Update the kept highlight with the best available metadata from duplicates
-- (prefer non-null, non-empty values)
UPDATE highlights h
SET
    chapter = COALESCE(
        NULLIF(h.chapter, ''),
        (SELECT chapter FROM highlights WHERE id = ANY(
            SELECT unnest(all_ids) FROM duplicate_groups WHERE keep_id = h.id
        ) AND chapter <> '' LIMIT 1)
    ),
    datetime = COALESCE(
        NULLIF(h.datetime, ''),
        (SELECT datetime FROM highlights WHERE id = ANY(
            SELECT unnest(all_ids) FROM duplicate_groups WHERE keep_id = h.id
        ) AND datetime <> '' LIMIT 1)
    ),
    color = COALESCE(
        NULLIF(h.color, ''),
        (SELECT color FROM highlights WHERE id = ANY(
            SELECT unnest(all_ids) FROM duplicate_groups WHERE keep_id = h.id
        ) AND color <> '' LIMIT 1)
    ),
    page_xpath = COALESCE(
        NULLIF(h.page_xpath, ''),
        (SELECT page_xpath FROM highlights WHERE id = ANY(
            SELECT unnest(all_ids) FROM duplicate_groups WHERE keep_id = h.id
        ) AND page_xpath <> '' LIMIT 1)
    ),
    -- For page_number, prefer non-zero values
    page_number = CASE
        WHEN h.page_number > 0 THEN h.page_number
        ELSE COALESCE(
            (SELECT page_number FROM highlights WHERE id = ANY(
                SELECT unnest(all_ids) FROM duplicate_groups WHERE keep_id = h.id
            ) AND page_number > 0 LIMIT 1),
            h.page_number
        )
    END
FROM duplicate_groups dg
WHERE h.id = dg.keep_id;

-- Delete device associations for duplicate highlights that will be removed
DELETE FROM highlight_devices
WHERE highlight_id IN (
    SELECT unnest(all_ids[2:]) -- Skip the first ID (which we're keeping)
    FROM duplicate_groups
);

-- Delete duplicate highlights (keep only the one with lowest ID)
DELETE FROM highlights
WHERE id IN (
    SELECT unnest(all_ids[2:]) -- Skip the first ID (which we're keeping)
    FROM duplicate_groups
);

-- Report results
SELECT
    COUNT(*) as duplicate_groups_merged,
    SUM(dup_count - 1) as total_duplicates_removed
FROM duplicate_groups;

-- Clean up
DROP TABLE duplicate_groups;
