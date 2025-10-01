# KoReader Highlights Collector

Collects and aggregates highlights from multiple KoReader e-reader devices synced via Syncthing into a single JSON file.

## Overview

This tool scans KoReader metadata files across multiple devices, extracts highlights with their metadata (text, chapter, page number, timestamp, device ID), and consolidates them into a structured JSON format grouped by book.

## Features

- **Multi-device support**: Aggregates highlights from multiple KoReader devices
- **Automatic deduplication**: Groups highlights by book using MD5 checksums
- **Rich metadata**: Preserves chapter, page number, timestamp, and device information
- **Zero dependencies**: Uses only Python standard library
- **Cron-ready**: Designed to run periodically for continuous collection

## Requirements

- Python 3.6+
- KoReader devices synced via Syncthing to `~/syncthing/ebooks-highlights/`

## Installation

```bash
git clone <repository-url>
cd koreader-highlights-collector
chmod +x collect_highlights.py
```

## Usage

### Basic Usage

```bash
# Collect highlights with default paths
python3 collect_highlights.py collect

# Specify custom paths
python3 collect_highlights.py collect --base-path /path/to/highlights --output /path/to/output.json

# View help
python3 collect_highlights.py --help
python3 collect_highlights.py collect --help
```

### Commands

- `collect`: Collect highlights from KoReader devices
- `publish`: Publish highlights to Karakeep

### Collect Command

Scan syncthing folders and collect all KoReader highlights into a JSON file.

#### Options

- `--base-path`: Base directory containing device folders (default: `~/syncthing/ebooks-highlights`)
- `--output`: Output JSON file path (default: `highlights.json`)

### Publish Command

Push your collected highlights to Karakeep with automatic tagging and duplicate prevention.

```bash
# Preview what would be published (dry-run)
python3 collect_highlights.py publish --dry-run

# Publish to Karakeep (uses credentials from .env)
python3 collect_highlights.py publish

# Publish to a different list
python3 collect_highlights.py publish --list-name "My Reading List"

# Publish with custom settings
python3 collect_highlights.py publish --input highlights.json --karakeep-url http://localhost:3000

# Force re-publish even if duplicates detected
python3 collect_highlights.py publish --force
```

#### Options

- `--input`: Input JSON file (default: `highlights.json`)
- `--karakeep-url`: Karakeep server URL (default: from `.env` or `http://192.168.100.230:23001`)
- `--email`: Karakeep email/username (default: from `.env` `KARAKEEP_ID`)
- `--password`: Karakeep password (default: from `.env` `KARAKEEP_PASSWORD`)
- `--list-name`: Karakeep list name or ID (default: "Book Quotes")
- `--dry-run`: Preview without making changes
- `--force`: Publish even if duplicates detected

#### Setting Up Credentials

Create a `.env` file in the project directory:

```bash
KARAKEEP_ID='your.email@example.com'
KARAKEEP_PASSWORD='your-password'
KARAKEEP_URL='http://192.168.100.230:23001'  # Optional
```

#### Features

- **Automatic Filtering**: Only publishes actual text highlights (excludes bookmarks and empty highlights)
- **Smart Tagging**: Automatically creates and applies tags:
  - `book:{Book Title}` - Organizes by book
  - `device:{Device ID}` - Tracks source device
- **List Organization**: Automatically adds highlights to "Book Quotes" list (or specify custom list ID)
- **Duplicate Prevention**: Checks existing bookmarks before publishing to avoid clutter
- **Rich Metadata**: Each highlight includes book info, chapter, page number, timestamp
- **Progress Tracking**: Shows publishing progress and final statistics

### Output Format

The script generates a JSON file with the following structure:

```json
{
  "generated_at": "2025-10-01T20:55:33",
  "total_books": 39,
  "total_highlights": 1474,
  "books": [
    {
      "book_id": "3b1988915d4a70cd1c5a815667c72d33",
      "title": "Fluent Python, 2nd Edition",
      "authors": "Luciano Ramalho",
      "identifiers": "9781492056355",
      "language": "en-US",
      "highlights": [
        {
          "highlight_type": "highlight",
          "text": "The highlight text...",
          "chapter": "Chapter Name",
          "page_number": 48,
          "datetime": "2025-05-09 20:47:52",
          "color": "yellow",
          "drawer": "lighten",
          "device_id": "boox-palma",
          "page_xpath": "/body/DocFragment[7]/..."
        }
      ]
    }
  ]
}
```

## Setting Up as a Cron Job

To automatically collect highlights daily:

### 1. Make the script executable

```bash
chmod +x /home/stonecharioteer/code/checkouts/personal/koreader-highlights-collector/collect_highlights.py
```

### 2. Edit your crontab

```bash
crontab -e
```

### 3. Add a cron entry

```cron
# Collect KoReader highlights daily at 2 AM
0 2 * * * cd /home/stonecharioteer/code/checkouts/personal/koreader-highlights-collector && /usr/bin/python3 collect_highlights.py collect --output highlights_$(date +\%Y\%m\%d).json >> /tmp/koreader-collector.log 2>&1
```

Or for a simpler setup (overwrite the same file):

```cron
# Collect highlights daily at 2 AM
0 2 * * * cd /home/stonecharioteer/code/checkouts/personal/koreader-highlights-collector && /usr/bin/python3 collect_highlights.py collect >> /tmp/koreader-collector.log 2>&1
```

### 4. Verify the cron job

```bash
# List cron jobs
crontab -l

# Check logs
tail -f /tmp/koreader-collector.log
```

## Annotation Types

The script identifies and tags four types of annotations:

- **`highlight`** (966): Standard text highlights with color and position data
- **`bookmark`** (414): Bookmarks without color highlighting (text shows "in [Chapter Name]")
- **`highlight_empty`** (84): Highlights without selected text
- **`highlight_no_position`** (10): Highlights without position/page data

Each annotation in the output includes a `highlight_type` field for filtering.

## How It Works

1. **Discovery**: Scans `~/syncthing/ebooks-highlights/` for device folders
2. **Parsing**: Locates all `metadata.*.lua` files in `.sdr` folders
3. **Extraction**: Uses a custom Lua parser to extract:
   - Book metadata (title, author, ISBN, language)
   - Annotations (text, chapter, page, timestamp, color, type)
4. **Classification**: Identifies annotation type based on field presence
5. **Aggregation**: Groups annotations by book using MD5 checksum
6. **Export**: Writes consolidated data to JSON with sorting by book title and annotation datetime

## Directory Structure

```
~/syncthing/ebooks-highlights/
├── boox-palma/
│   └── storage/E435-F0CC/Books/Tech/
│       └── Book Name.sdr/
│           └── metadata.epub.lua
├── s24u/
├── s9u/
└── boox-tab-mini-c/
```

## Karakeep Integration

The tool now supports publishing highlights directly to [Karakeep](https://karakeep.app/), a self-hosted bookmark manager. This creates a searchable, tagged collection of all your reading highlights.

### Example Workflow

```bash
# 1. Collect highlights from your devices
python3 collect_highlights.py collect

# 2. Preview what will be published
python3 collect_highlights.py publish --dry-run

# 3. Publish to Karakeep
python3 collect_highlights.py publish
```

### Automated Pipeline

Combine collection and publishing in a cron job:

```cron
# Collect and publish highlights daily at 2 AM
0 2 * * * cd /home/user/koreader-highlights-collector && python3 collect_highlights.py collect && python3 collect_highlights.py publish >> /tmp/koreader.log 2>&1
```

## Future Enhancements

- Markdown export format
- Filtering by date range, book, or device
- Incremental updates (only process new/modified files)
- Additional export targets (Obsidian, Notion, etc.)