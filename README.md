# Podcast Search

A self-hosted web application that makes your favorite podcasts searchable and queryable through AI. Track podcasts via RSS, automatically transcribe episodes, and chat with an LLM to discover content across your entire podcast library.

## ⚠️ Project Status

This project is in active development. Core podcast management and transcription features are working. LLM/search features are coming next.

## Features

### ✅ Implemented

- **RSS Feed Management**: Subscribe to podcasts via RSS with automatic episode discovery
- **Episode Import**: Extracts metadata, cover art, and audio following PSP-1 spec
- **Automatic Transcription**: Self-hosted Whisper generates timestamped JSON transcripts
- **Background Jobs**: Solid Queue handles imports, transcription, and scheduled tasks
- **Daily Refresh**: Automatically checks for new episodes
- **Web Interface**: Browse podcasts and episodes with audio player

### 🚧 In Progress

- **Transcript Display**: Show transcripts on episode pages
- **Ad Detection**: Automatic ad removal using audio cue matching (experimental)

### 📋 TODO

- **AI-Powered Search & Chat**: Natural language queries with LLM using vector embeddings for semantic search
- **Episode Cross-Linking**: Discover related episodes and topics
- **Speaker Diarization**: Identify different speakers in episodes

## Use Cases

- Find specific discussions or topics across hundreds of episodes
- Research what multiple podcasts have said about a particular subject
- Build a personal, searchable podcast knowledge base
- Discover connections between episodes and topics

## Tech Stack

- **Backend**: Ruby on Rails 8
- **Database**: SQLite (development), PostgreSQL-ready
- **Background Jobs**: Solid Queue
- **Transcription**: Whisper (self-hosted)
- **Speaker Diarization**: pyannote-audio (planned)
- **LLM**: Qwen or similar self-hosted model (planned)
- **UI**: Bootstrap 5 with Hotwire/Turbo
- **Deployment**: Docker (planned)

## Prerequisites

- Ruby 3.4+
- Rails 8
- [Whisper](https://github.com/openai/whisper) for transcription: `pip install openai-whisper`
- Sufficient storage for podcast audio files and transcripts
- GPU recommended (but not required) for faster transcription

## Installation

```bash
# Clone the repository
git clone https://gitlab.com/bradleesand/podcast-search.git
cd podcast-search

# Install dependencies
bundle install

# Setup database
rails db:setup

# Install Whisper
pip install openai-whisper

# Run the application (with background jobs)
bin/dev
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Enable automatic transcription when new episodes are imported
AUTO_TRANSCRIBE=false

# Enable transcription feature globally
ENABLE_TRANSCRIPTION=true

# Enable automatic audio download when new episodes are imported
AUTO_DOWNLOAD_AUDIO=false

# Enable downloading audio files to local storage during transcription
# When true: downloads to storage/episodes/{podcast_id}/{episode_id}.{ext}
# When false: downloads to temporary file only for transcription
DOWNLOAD_AUDIO=false
```

**Note**: When `AUTO_TRANSCRIBE` and `AUTO_DOWNLOAD_AUDIO` are `false`, you can manually trigger these actions from the episode page using the "Transcribe" and "Download Audio" buttons.

### OpenSSL 3.6.0 Compatibility

If you encounter SSL certificate verification errors with OpenSSL 3.6.0, add the `openssl` gem which is included in the Gemfile.

### Recurring Jobs

Daily podcast refresh is configured in `config/recurring.yml` and runs at 2am by default. Edit this file to change the schedule.

## Usage

1. **Import a podcast**: Click "Import New Podcast" and paste an RSS feed URL
2. **View podcasts**: Browse your podcast library on the home page
3. **View episodes**: Click a podcast to see all episodes with audio players
4. **Manual refresh**: Click "Refresh Episodes" to check for new episodes immediately
5. **Manual processing**: Use the "Download Audio" and "Transcribe" buttons on episode pages to process individual episodes
6. **Transcripts**: Episodes can be transcribed automatically (if `AUTO_TRANSCRIBE=true`) or manually via the episode page

## Development Roadmap

- [x] Basic Rails application structure
- [x] RSS feed ingestion and episode import
- [x] Whisper integration for transcription
- [x] Database schema for podcasts and episodes
- [x] Background job processing with Solid Queue
- [x] Web UI for podcast management
- [x] Daily automatic refresh of feeds
- [ ] Display transcripts in episode UI
- [ ] Vector embeddings for semantic search
- [ ] LLM chat interface
- [ ] Search and indexing functionality
- [ ] pyannote-audio integration for speaker diarization
- [ ] Episode cross-linking
- [ ] Ad detection and trimming (experimental)
- [ ] Docker deployment configuration

## Architecture

### Processing Pipeline

Episodes are processed through a flexible pipeline system via `EpisodeProcessingJob`. The job accepts a list of steps to execute in sequence:

**Available Steps:**
- `:download` - Download audio to local storage
- `:trim_ads` - Remove ads using audio cue detection (future)
- `:transcribe` - Generate transcript with Whisper

**Example Pipelines:**
```ruby
# Full processing pipeline
EpisodeProcessingJob.perform_later(episode_id, [:download, :trim_ads, :transcribe])

# Download only
EpisodeProcessingJob.perform_later(episode_id, [:download])

# Transcribe only (downloads to temp if needed)
EpisodeProcessingJob.perform_later(episode_id, [:transcribe])

# Custom pipeline: download and trim, but don't transcribe
EpisodeProcessingJob.perform_later(episode_id, [:download, :trim_ads])
```

Each step is executed as a separate job, allowing for:
- Easy retrying of failed steps
- Different pipelines for different use cases
- Future steps to be added without changing existing code

### Workflow

1. **Ingestion**: RSS feeds are imported and validated
2. **Import**: Episodes are extracted with metadata (title, description, audio URL, etc.)
3. **Processing**: Based on env vars, episodes are queued with appropriate pipeline steps
4. **Storage**: Audio and transcripts saved to `storage/`
5. **Daily Refresh**: Solid Queue checks feeds for new episodes at 2am

### Service Architecture

**Processing Pipeline:**
- `EpisodeProcessingJob`: Orchestrates multi-step processing (download → trim ads → transcribe)
  - Each step runs as a separate job for easy retry and custom pipelines
  - Steps can be composed: download-only, transcribe-only, or full pipeline

**Services:**
- `PodcastImportService`: Handles initial RSS import and podcast creation
- `PodcastRssSyncService`: Refreshes existing podcasts with new episodes
- `RssParser`: Shared concern for parsing RSS feeds
- `EpisodeAudioDownloadService`: Downloads and stores episode audio files locally
- `EpisodeTranscriptionService`: Orchestrates transcription workflow (download → transcribe)
- `AudioFormat`: Shared concern for MIME type validation and file extensions

**Background Jobs:**
- `EpisodeProcessingJob`: Pipeline orchestrator for episode processing
- `PodcastRefreshJob`: Refreshes a single podcast
- `RefreshAllPodcastsJob`: Daily job to refresh all podcasts

## Contributing

This is a personal project in active development. Contributions, ideas, and feedback are welcome!

## License

[License TBD]

## Acknowledgments

- [Whisper](https://github.com/openai/whisper) - Speech recognition
- [pyannote-audio](https://github.com/pyannote/pyannote-audio) - Speaker diarization (planned)
- [Qwen](https://github.com/QwenLM/Qwen) - LLM capabilities (planned)
- [PSP-1 Podcast RSS Specification](https://github.com/Podcast-Standards-Project/PSP-1-Podcast-RSS-Specification)

---

**Self-hosted. Private. Searchable.**