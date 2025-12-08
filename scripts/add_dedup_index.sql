-- Add index for efficient highlight deduplication
-- This supports queries that look up highlights by (book_id, text, kind)

CREATE INDEX IF NOT EXISTS idx_highlights_dedup
ON highlights(book_id, text, kind);

-- Add comments explaining the deduplication strategy
COMMENT ON INDEX idx_highlights_dedup IS 'Supports deduplication queries by (book_id, text, kind). Page numbers are NOT included because they can differ across devices/editions of the same book.';
