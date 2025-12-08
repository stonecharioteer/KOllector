# Periodic Scanning Implementation

This document describes the periodic scanning feature implementation for KOllector.

## Overview

The application now supports automatic periodic scanning of configured source paths for new highlights. This is implemented using Celery Beat with configurable cron-based scheduling.

## Features

1. **Cron-based scheduling**: Configure scan frequency using standard cron syntax
2. **Real-time validation**: Validates cron expressions and shows next 3 scheduled runs
3. **Duplicate detection**: Existing highlights are automatically skipped
4. **Database-driven configuration**: Schedule is stored in AppConfig table
5. **Web UI management**: Configure schedule through the Config page

## Architecture

### Components

1. **Celery Beat Service** (`docker-compose.yml`)
   - Runs as a separate container (`beat`)
   - Reads schedule from database on startup
   - Triggers periodic tasks based on cron expression

2. **Beat Schedule Configuration** (`celerybeat_schedule.py`)
   - Loads cron schedule from database on startup
   - Parses cron expression and creates Celery Beat schedule
   - Falls back to default (every 15 minutes) if invalid

3. **Database Model** (`app/models.py`)
   - `AppConfig.scan_schedule`: Stores cron expression
   - Default: `*/15 * * * *` (every 15 minutes)

4. **Configuration Endpoint** (`app/views/config.py`)
   - `POST /config`: Updates scan schedule
   - `GET /config/validate-cron`: Validates cron syntax via AJAX
   - Returns next 3 scheduled runs for preview

5. **Web UI** (`app/templates/config/index.html`)
   - Form input for cron expression
   - Real-time validation with debouncing
   - Shows next 3 scheduled runs
   - Displays validation errors

## How It Works

### Startup Flow

1. Celery Beat container starts
2. `celerybeat_schedule.py` is loaded
3. `get_beat_schedule()` queries database for `AppConfig.scan_schedule`
4. Cron expression is validated using `croniter`
5. Celery Beat schedule is configured with the cron expression
6. Beat starts scheduling tasks

### Scanning Flow

1. Celery Beat triggers `tasks.scan_all_paths` based on schedule
2. Task queries `SourcePath` table for enabled paths
3. Skips scan if no enabled paths configured
4. For each enabled path:
   - Scans for `metadata.*.lua` files
   - Parses each file using `LuaTableParser`
   - Upserts books and highlights to database
   - **Duplicate detection**: Highlights are deduplicated by `(book_id, text, page_number)`
   - Updates existing highlights with missing fields
   - Tracks device IDs via `HighlightDevice` junction table
5. Logs total files scanned

### Duplicate Detection

Highlights are deduplicated in `tasks.py:138-157`:

```python
existing = Highlight.query.filter(
    Highlight.book_id == book.id,
    Highlight.text == (ann.text or ''),
    Highlight.page_number == (ann.pageno or 0),
    Highlight.kind.in_(['highlight', 'highlight_empty', 'highlight_no_position'])
).first()

if existing:
    # Attach device tag if missing
    if device_id and not any(d.device_id == device_id for d in existing.devices):
        db.session.add(HighlightDevice(highlight_id=existing.id, device_id=device_id))
    # Update missing fields (chapter, datetime, page_xpath, color)
    # ...
else:
    # Create new highlight
```

This ensures:
- Same highlight from multiple scans is not duplicated
- Device tracking is preserved across scans
- Missing metadata is backfilled on subsequent scans

## Configuration

### Default Schedule

The default schedule is every 15 minutes: `*/15 * * * *`

### Changing the Schedule

#### Via Web UI (Recommended)

1. Navigate to `/config`
2. Find "Periodic Scanning" section
3. Enter new cron expression
4. Click "Validate" to preview next runs
5. Click "Save Schedule"
6. Restart Celery Beat: `docker compose restart beat`

#### Via Database

```sql
UPDATE app_config SET scan_schedule = '0 */6 * * *' WHERE id = 1;
```

Then restart Celery Beat.

### Common Cron Patterns

| Pattern | Description |
|---------|-------------|
| `*/15 * * * *` | Every 15 minutes (default) |
| `*/30 * * * *` | Every 30 minutes |
| `0 * * * *` | Every hour (on the hour) |
| `0 */6 * * *` | Every 6 hours |
| `0 0 * * *` | Daily at midnight UTC |
| `0 9 * * *` | Daily at 9 AM UTC |
| `0 9,17 * * *` | Twice daily at 9 AM and 5 PM UTC |
| `0 0 * * 0` | Weekly on Sunday at midnight |
| `0 0 1 * *` | Monthly on the 1st at midnight |

### Cron Syntax Reference

```
 ┌───────────── minute (0-59)
 │ ┌───────────── hour (0-23)
 │ │ ┌───────────── day of month (1-31)
 │ │ │ ┌───────────── month (1-12)
 │ │ │ │ ┌───────────── day of week (0-6, Sunday=0)
 │ │ │ │ │
 * * * * *
```

Special characters:
- `*` - Any value
- `,` - Value list separator (e.g., `1,3,5`)
- `-` - Range (e.g., `1-5`)
- `/` - Step values (e.g., `*/15`)

## Dependencies

- **croniter**: Validates and parses cron expressions
- **Celery Beat**: Schedules periodic tasks
- **RabbitMQ**: Message broker for Celery

## Files Modified

1. `app/models.py` - Added `scan_schedule` field to `AppConfig`
2. `celery_app.py` - Configured beat schedule
3. `celerybeat_schedule.py` - **NEW** - Dynamic schedule loader
4. `app/views/config.py` - Added schedule update and validation endpoints
5. `app/templates/config/index.html` - Added schedule configuration UI
6. `docker-compose.yml` - Added `beat` service
7. `pyproject.toml` - Added `croniter` dependency
8. `README.md` - Updated documentation

## Testing

### Manual Testing

1. Start the application:
   ```bash
   docker compose up --build
   ```

2. Configure a source path at `/config`

3. Set scan schedule to `* * * * *` (every minute) for testing

4. Save and restart beat:
   ```bash
   docker compose restart beat
   ```

5. Watch Celery Beat logs:
   ```bash
   docker compose logs -f beat
   ```

6. Watch Celery Worker logs:
   ```bash
   docker compose logs -f worker
   ```

7. Verify scans happen every minute and no duplicates are created

### Validation Testing

1. Navigate to `/config`
2. Test invalid cron expressions:
   - `invalid` - Should show error
   - `60 * * * *` - Invalid minute (should show error)
   - `* * 32 * *` - Invalid day (should show error)
3. Test valid expressions:
   - `*/15 * * * *` - Should show next 3 runs
   - `0 0 * * 0` - Should show weekly runs

## Troubleshooting

### Schedule not updating

**Problem**: Changed schedule in UI but scans still happen on old schedule

**Solution**: Restart Celery Beat container
```bash
docker compose restart beat
```

### Beat container failing to start

**Problem**: Beat container exits immediately

**Solution**: Check logs for configuration errors
```bash
docker compose logs beat
```

Common issues:
- Invalid cron expression in database
- Database connection issues
- Missing dependencies

### Scans not happening

**Problem**: Beat is running but scans never trigger

**Solution**:
1. Check if source paths are enabled:
   ```sql
   SELECT * FROM source_paths WHERE enabled = true;
   ```
2. Check Beat schedule in logs:
   ```bash
   docker compose logs beat | grep schedule
   ```
3. Verify Beat is sending tasks:
   ```bash
   docker compose logs beat | grep "Sending due task"
   ```

### Duplicates being created

**Problem**: Same highlights appear multiple times after scanning

**Solution**: This should not happen due to deduplication logic. If it does:
1. Check database schema for unique constraints
2. Verify `tasks.py` deduplication logic is active
3. File a bug report with:
   - Database dump of affected highlights
   - Celery worker logs
   - Sample metadata files

## Performance Considerations

- **Scan frequency**: More frequent scans increase database load
- **Source path count**: More paths = longer scan duration
- **File system I/O**: Read-only mounts are sufficient
- **Database locks**: Scans use transactions but should not block UI

Recommended scan frequencies by setup:
- **Single device, infrequent reading**: `0 0 * * *` (daily)
- **Multiple devices, moderate reading**: `0 */6 * * *` (every 6 hours)
- **Active reading, multiple devices**: `*/30 * * * *` (every 30 minutes)
- **Development/testing**: `*/15 * * * *` (every 15 minutes, default)

## Future Enhancements

Potential improvements:
- [ ] Manual trigger from Config page (bypass schedule)
- [ ] Scan history log with timestamps and file counts
- [ ] Per-source-path scheduling (different schedules for different devices)
- [ ] Smart scheduling based on file modification times
- [ ] Notification system for scan failures
- [ ] Metrics dashboard (scans per day, highlights added, etc.)
