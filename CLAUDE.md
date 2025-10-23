# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A self-hosted Rails application that makes podcasts searchable through AI. Tracks podcasts via RSS, automatically transcribes episodes using Whisper, and provides semantic search with local LLMs (Ollama). Features include RAG-powered search with tool calling, weighted search results, ad detection, and interactive transcript playback.

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
- Transcripts stored in `generated_transcript` column as JSON
- Local audio stored in `local_audio_path` when downloaded
- After creation, automatically enqueues processing based on env vars

**PodcastImportTask** (app/models/podcast_import_task.rb)
- Tracks import job status for new podcast feeds

**TranscriptChunk** (app/models/transcript_chunk.rb)
- Stores chunked transcript segments for semantic search
- Chunk types: title, description, transcript, advertisement
- One chunk per Whisper segment (for transcript type)
- Contains: text, start_time, end_time, chunk_index, embedding, chunk_type
- Belongs to Episode, has one Podcast through Episode
- Title/description chunks have nil timestamps and negative chunk_index

### Processing Pipeline

Episodes are processed through `EpisodeProcessingJob` with a flexible step-based pipeline:

**Available Steps:**
- `:download` - Download audio to local storage
- `:trim_ads` - Remove ads using audio cue detection (planned, currently no-op)
- `:transcribe` - Generate transcript with Whisper
- `:chunk_transcript` - Split transcript into searchable chunks (Phase 1 of RAG)
- `:generate_embeddings` - Generate vector embeddings for chunks (Phase 2 of RAG, not yet implemented)

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
- Stores JSON transcript in `episodes.generated_transcript` column
- Updates `transcription_status` enum

**TranscriptChunkingService** (app/services/transcript_chunking_service.rb)
- Splits Whisper transcripts into searchable chunks
- Creates title and description chunks (chunk_type: title/description)
- Creates one TranscriptChunk per Whisper segment (chunk_type: transcript)
- Stores text and timestamps for each chunk

**EmbeddingService** (app/services/embedding_service.rb)
- Wraps Python sentence-transformers for embedding generation
- Uses `all-MiniLM-L6-v2` model (384 dimensions)
- Generates vector embeddings for transcript chunks
- Stores embeddings as JSON arrays in database

**TranscriptSearchService** (app/services/transcript_search_service.rb)
- Performs semantic vector similarity search across transcript chunks
- Uses neighbor gem with cosine distance
- Weighted ranking: title chunks 3x, description 2x, transcript 1x
- Filters by podcast, episode, listened status
- Excludes advertisements by default
- Returns top N results (configurable, default: 10)

**LlmQueryService** (app/services/llm_query_service.rb)
- Queries Ollama (local LLM) with search results as context
- Generates cited responses with numbered sources
- Supports tool calling for iterative context gathering
- LLM can request more info via search_transcript tool (up to 3 iterations)
- Returns AI-generated answer with all sources used

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
- `ENABLE_SEMANTIC_SEARCH=false` - Enable RAG features (requires Python setup)
- `PYTHON_PATH=venv/bin/python3` - Path to Python for embedding generation

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

- Transcripts stored in `episodes.generated_transcript` column (JSON text)
- `storage/episodes/{podcast_id}/{episode_id}.{ext}` - Local audio (when DOWNLOAD_AUDIO=true)
- Local audio paths stored in Episode model's `local_audio_path`

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

# Process with chunking
EpisodeProcessingJob.perform_later(episode.id, [:transcribe, :chunk_transcript])
```

### Chunking Existing Transcripts

Use the rake task to chunk all existing transcripts:
```bash
rails transcripts:chunk
```

### Generating Embeddings

Generate embeddings for all chunks:
```bash
# First time: install Python dependencies
python3 -m venv venv
source venv/bin/activate
pip install sentence-transformers torch

# Generate embeddings
rails transcripts:generate_embeddings
```

### Querying Transcripts via CLI

Use the CLI tool to query transcripts from the command line:

```bash
# Basic query across all podcasts
rails runner scripts/query_llm.rb "What are some productivity tips?"

# Query with verbose output (shows all sources)
rails runner scripts/query_llm.rb "What tools were recommended?" --verbose

# Query specific podcast
rails runner scripts/query_llm.rb "What did they say about focus?" --context podcast --podcast 1

# Query specific episode
rails runner scripts/query_llm.rb "What was the main topic?" --context episode --episode 123

# Filter by listened status
rails runner scripts/query_llm.rb "What are the main themes?" --filter unlistened

# Adjust context chunks
rails runner scripts/query_llm.rb "Tell me about the guest" --limit 15
```

**Available Options:**
- `-c, --context CONTEXT` - Search context: all, podcast, episode
- `-p, --podcast ID` - Podcast ID (required for podcast/episode context)
- `-e, --episode ID` - Episode ID (required for episode context)
- `-l, --limit N` - Number of initial context chunks (default: 10)
- `-f, --filter FILTER` - Listened filter: all, listened, unlistened
- `-v, --verbose` - Show detailed sources with similarity scores
- `-h, --help` - Show help message

The LLM will automatically use tool calling to request additional context if needed (up to 3 iterations).

## Future Planned Features

- Speaker diarization with pyannote-audio
- Enhanced search UI (filters, history, saved searches)
- Episode cross-linking and recommendations
- Audio-based ad trimming (fingerprinting approach)
