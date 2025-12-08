-- Add hidden column to highlights table
ALTER TABLE highlights
ADD COLUMN IF NOT EXISTS hidden BOOLEAN NOT NULL DEFAULT false;

-- Add index for filtering hidden highlights
CREATE INDEX IF NOT EXISTS idx_highlights_hidden ON highlights(hidden);

-- Add comment
COMMENT ON COLUMN highlights.hidden IS 'Whether this highlight is hidden from the UI';
