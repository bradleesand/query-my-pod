# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A self-hosted Rails application that makes podcasts searchable through AI. Tracks podcasts via RSS, automatically transcribes episodes using Whisper, and provides a web interface for browsing and listening. LLM-powered semantic search is planned but not yet implemented.

## Development Commands

### Setup
```bash
# First-time setup
bundle install
rails db:setup
pip install openai-whisper

# Start development server (Rails + Solid Queue + CSS watch)
bin/dev

# Database operations
rails db:migrate
rails db:reset
rails db:schema:load
```

### Testing
```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/episode_test.rb

# Run specific test method
rails test test/models/episode_test.rb:12

# Run system tests
rails test:system
```

### Code Quality
```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop offenses
bundle exec rubocop -a

# Run Brakeman security scanner
bundle exec brakeman

# Annotate models with schema info
rails annotate_models
```

### Rails Console
```bash
# Development console
rails console

# Production console
rails console -e production
```

## Architecture

### Core Models

**Podcast** (app/models/podcast.rb)
- Represents RSS podcast feeds
- One-to-many relationship with Episodes
- Identified by `guid` (unique RSS feed identifier)

**Episode** (app/models/episode.rb)
- Individual podcast episodes with metadata from RSS
- Status tracking via enums:
  - `transcription_status`: pending → processing → completed/failed
  - `download_status`: pending → downloading → completed/failed
- Transcripts stored in `storage/transcripts/{id}.json`
- Local audio stored in `local_audio_path` when downloaded
- After creation, automatically enqueues processing based on env vars

**PodcastImportTask** (app/models/podcast_import_task.rb)
- Tracks import job status for new podcast feeds

### Processing Pipeline

Episodes are processed through `EpisodeProcessingJob` with a flexible step-based pipeline:

**Available Steps:**
- `:download` - Download audio to local storage
- `:trim_ads` - Remove ads using audio cue detection (planned, currently no-op)
- `:transcribe` - Generate transcript with Whisper

**Pipeline Flow:**
1. Episode created from RSS feed
2. `after_create` callback in Episode model builds pipeline based on env vars
3. `EpisodeProcessingJob` executes steps sequentially
4. Each step is a separate job for retry capability
5. Failed steps don't prevent other episodes from processing

**Example Usage:**
```ruby
# Full pipeline
EpisodeProcessingJob.perform_later(episode.id, [:download, :trim_ads, :transcribe])

# Download only
EpisodeProcessingJob.perform_later(episode.id, [:download])

# Transcribe only (downloads to temp if needed)
EpisodeProcessingJob.perform_later(episode.id, [:transcribe])
```

### Services

**PodcastImportService** (app/services/podcast_import_service.rb)
- Handles initial RSS import and podcast creation
- Uses RssParser concern for feed parsing

**PodcastRssSyncService** (app/services/podcast_rss_sync_service.rb)
- Refreshes existing podcasts with new episodes
- Deduplicates by guid to avoid reimporting

**EpisodeAudioDownloadService** (app/services/episode_audio_download_service.rb)
- Downloads and stores episode audio files locally
- Updates `download_status` enum
- Validates audio format using AudioFormat concern

**EpisodeTranscriptionService** (app/services/episode_transcription_service.rb)
- Orchestrates transcription workflow
- Calls Whisper via shell command
- Stores JSON transcript in `storage/transcripts/`
- Updates `transcription_status` enum

### Background Jobs (Solid Queue)

**EpisodeProcessingJob** (app/jobs/episode_processing_job.rb)
- Pipeline orchestrator for multi-step episode processing
- Executes steps sequentially as separate jobs

**PodcastRefreshJob** (app/jobs/podcast_refresh_job.rb)
- Refreshes a single podcast's episodes

**RefreshAllPodcastsJob** (app/jobs/refresh_all_podcasts_job.rb)
- Scheduled daily at 2am (see config/recurring.yml)
- Enqueues PodcastRefreshJob for each podcast

**PodcastImportJob** (app/jobs/podcast_import_job.rb)
- Async wrapper for PodcastImportService

### Concerns

**RssParser** (app/services/concerns/rss_parser.rb)
- Shared RSS feed parsing logic
- Follows PSP-1 specification
- Used by both import and sync services

**AudioFormat** (app/services/concerns/audio_format.rb)
- MIME type validation
- File extension mapping

### Configuration

**Environment Variables** (see .env.example):
- `AUTO_TRANSCRIBE=false` - Auto-transcribe new episodes
- `ENABLE_TRANSCRIPTION=true` - Enable transcription feature
- `AUTO_DOWNLOAD_AUDIO=false` - Auto-download new episode audio
- `DOWNLOAD_AUDIO=false` - Keep audio files after transcription (vs temp download)

**Recurring Jobs** (config/recurring.yml):
- `RefreshAllPodcastsJob` runs daily at 2am
- Production also clears finished Solid Queue jobs hourly

### Routes

- `GET /` - Podcast index (root)
- `GET /podcasts/:id` - Podcast show page with episodes
- `POST /podcasts/:id/refresh` - Manually refresh podcast
- `GET /episodes/:id` - Episode show page
- `POST /episodes/:id/download_audio` - Manual audio download
- `POST /episodes/:id/transcribe` - Manual transcription
- `GET /episodes/:id/audio` - Serve local audio file
- `GET/POST /podcast_import_tasks/new` - Import new podcast

### Storage

- `storage/transcripts/{episode_id}.json` - Whisper transcripts
- `storage/episodes/{podcast_id}/{episode_id}.{ext}` - Local audio (when DOWNLOAD_AUDIO=true)
- Local paths stored in Episode model's `local_audio_path`

### Tech Stack

- **Framework**: Rails 8 with Turbo/Stimulus (Hotwire)
- **Database**: SQLite (development), PostgreSQL-ready
- **Background Jobs**: Solid Queue (database-backed)
- **UI**: Bootstrap 5, Dartsass
- **Pagination**: Pagy
- **Server**: Puma
- **Transcription**: Whisper (via shell command to Python)

## Common Patterns

### Adding a New Processing Step

1. Add step to `STEPS` hash in `EpisodeProcessingJob`
2. Implement private method (e.g., `def my_step`)
3. Return true/false for success/failure
4. Update `DEFAULT_PIPELINE` if step should be included by default
5. Update Episode model's `enqueue_background_jobs` if needed

### Testing Transcription

Whisper must be installed: `pip install openai-whisper`

The transcription service calls Whisper via shell command, so ensure the `whisper` command is in PATH.

### Manual Episode Processing

Use Rails console to manually process episodes:
```ruby
episode = Episode.find(123)
EpisodeProcessingJob.perform_later(episode.id, [:transcribe])
```

## Future Planned Features

- Vector embeddings for semantic search (not yet implemented)
- LLM chat interface for querying transcripts
- Speaker diarization with pyannote-audio
- Ad detection and automatic trimming
- Episode cross-linking
