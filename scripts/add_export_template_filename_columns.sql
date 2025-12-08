-- Add filename template columns to export_templates table
ALTER TABLE export_templates
ADD COLUMN IF NOT EXISTS filename_template VARCHAR(500) NOT NULL DEFAULT '{{ book_title }}.md';

ALTER TABLE export_templates
ADD COLUMN IF NOT EXISTS cover_filename_template VARCHAR(500) NOT NULL DEFAULT '{{ book_title }}';

-- Update existing templates to use the default values
UPDATE export_templates
SET filename_template = '{{ book_title }}.md'
WHERE filename_template IS NULL OR filename_template = '';

UPDATE export_templates
SET cover_filename_template = '{{ book_title }}'
WHERE cover_filename_template IS NULL OR cover_filename_template = '';

COMMENT ON COLUMN export_templates.filename_template IS 'Jinja2 template for exported filename (with extension). Variables: book_title, book_authors, export_date';
COMMENT ON COLUMN export_templates.cover_filename_template IS 'Jinja2 template for cover filename (without extension). Variables: book_title, book_authors, export_date';
