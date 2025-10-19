# Podcast Import System

## Architecture

The podcast import system uses Rails 8's built-in Solid Queue for background job processing.

### Components

1. **PodcastImportTask model** - Tracks import requests with status (pending, processing, completed, failed)
2. **PodcastImportJob** - Background job that fetches and parses RSS feeds
3. **Podcast model** - Stores the podcast data

### Import Flow

1. User submits RSS feed URL via form
2. `PodcastImportTask.create!(url: url)` creates a new task
3. **Before create**: Check if podcast already exists by URL
   - If exists: Link to existing podcast, mark as completed, skip job
   - If not: Continue with pending status
4. **After create**: If pending, enqueue `PodcastImportJob.perform_later(task.id)`
5. Job fetches RSS, parses it, checks again for existing podcast by GUID or URL
6. Creates new podcast if needed, or links to existing one
7. Task status updated to completed or failed

### Concurrency Controls

The job uses Solid Queue's `limits_concurrency` with `on_conflict: :discard`:

- Only 1 job per unique task ID can run at a time
- Deduplication is based on task ID, not URL (allows tracking multiple import attempts)
- If same task ID is enqueued twice, second job is discarded
- 30 minute window

### Podcast Deduplication

Podcasts are deduplicated at two levels:

1. **Before task creation**: Check `rss_url` in database
   - Links to existing podcast immediately
   - Marks task as completed without running job
   
2. **During job execution**: Check both `guid` and `rss_url`
   - Handles case where podcast was created between task creation and job execution
   - Handles case where GUID was extracted from RSS but URL changed

### RSS Feed Parsing

Follows PSP-1 Podcast RSS Specification:
- Uses `podcast:guid` as unique identifier (falls back to URL)
- Populates all standard fields: title, description, link, language, category, explicit, image_url, author, copyright
- Handles iTunes namespace tags

### Status Tracking

String-based enum for human-readable database values:
- `pending` - Task created, job queued
- `processing` - Job actively running  
- `completed` - Successfully imported (or linked to existing)
- `failed` - Error occurred during import

### Relationships

- `PodcastImportTask belongs_to :podcast` - Every task links to the podcast it imported/found
- Multiple tasks can link to the same podcast (tracks import history)

### UI

Hotwire/Turbo-powered interface:
- "Import New Podcast" button on index page
- Clicking reveals inline form with URL input
- Form submits and redirects back to index with flash message
- Bootstrap styling
