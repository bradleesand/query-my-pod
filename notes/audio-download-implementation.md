# Audio Download and Manual Transcription Implementation

## Overview

This implementation adds the ability to:
1. Download podcast episode audio files to local storage
2. Control transcription and downloads via environment variables
3. Manually trigger downloads and transcription from the episode page
4. Process episodes through a flexible pipeline system

## Architecture

### Processing Pipeline

The `EpisodeProcessingJob` implements a pipeline pattern where episodes are processed through a series of steps. Each step is executed as a separate job, making it easy to retry failures and compose custom pipelines.

**Available Steps:**
- `:download` - Download audio to local storage
- `:trim_ads` - Remove ads using audio cue detection (future implementation)
- `:transcribe` - Generate transcript with Whisper

**Step Execution:**
1. Job receives episode_id and list of remaining steps
2. Executes the first step
3. If successful, enqueues a new job with remaining steps
4. If failed, logs error and stops (can be manually retried)

**Example Pipelines:**
```ruby
# Full processing (download → trim ads → transcribe)
EpisodeProcessingJob.perform_later(episode_id, [:download, :trim_ads, :transcribe])

# Download only
EpisodeProcessingJob.perform_later(episode_id, [:download])

# Transcribe only (will download to temp if DOWNLOAD_AUDIO=false)
EpisodeProcessingJob.perform_later(episode_id, [:transcribe])
```

**Benefits:**
- Each step is a separate job - easy to retry individual steps
- Steps can be composed for different use cases
- Failed steps don't block the entire pipeline
- Future steps (like ad detection) slot in seamlessly

### Services

#### EpisodeAudioDownloadService
- Downloads episode audio to `storage/episodes/{podcast_id}/{episode_id}.{ext}`
- Calculates SHA256 checksum for verification
- Tracks download status (pending, downloading, completed, failed)
- Stores file size and local path in database

#### EpisodeTranscriptionService
- Orchestrates the transcription workflow
- Downloads audio (to local storage if enabled, otherwise temp file)
- Prepared for future ad trimming integration: `AdTrimmerService.new(episode, audio_path).trim`
- Transcribes with Whisper
- Cleans up temp files when not storing locally

### Database Schema

Added to episodes table:
- `local_audio_path` - Path to downloaded audio file
- `local_audio_size` - File size in bytes
- `local_audio_checksum` - SHA256 checksum
- `download_status` - Enum: pending, downloading, completed, failed

### Environment Variables

```bash
# Enable automatic transcription when new episodes are imported
# Default: false (manual trigger required)
AUTO_TRANSCRIBE=false

# Enable transcription feature globally
# Default: true
ENABLE_TRANSCRIPTION=true

# Enable automatic audio download when new episodes are imported
# Default: false (manual trigger required)
AUTO_DOWNLOAD_AUDIO=false

# Enable downloading audio files to local storage during transcription
# When true: downloads to storage/episodes/{podcast_id}/{episode_id}.{ext}
# When false: downloads to temporary file only for transcription
# Default: false
DOWNLOAD_AUDIO=false
```

## Usage Scenarios

### Scenario 1: Development/Testing (No Local Storage)
```bash
AUTO_TRANSCRIBE=false
AUTO_DOWNLOAD_AUDIO=false
DOWNLOAD_AUDIO=false
ENABLE_TRANSCRIPTION=true
```
- Episodes are not automatically processed
- Use manual buttons to transcribe specific episodes
- Audio downloaded to temp files only (cleaned up after transcription)
- Saves disk space during development

### Scenario 2: Production (Full Local Storage)
```bash
AUTO_TRANSCRIBE=true
AUTO_DOWNLOAD_AUDIO=true
DOWNLOAD_AUDIO=true
ENABLE_TRANSCRIPTION=true
```
- New episodes are automatically downloaded and transcribed
- Audio stored permanently for:
  - Consistent playback (no DAI variations)
  - Future ad detection/trimming
  - Offline access
- Serves audio from local storage via `/episodes/:id/audio`

### Scenario 3: Manual Control (Production)
```bash
AUTO_TRANSCRIBE=false
AUTO_DOWNLOAD_AUDIO=false
DOWNLOAD_AUDIO=true
ENABLE_TRANSCRIPTION=true
```
- Episodes are imported but not automatically processed
- Admin manually selects which episodes to download/transcribe
- When processed, audio is stored locally
- Good for selective processing of large podcasts

### Scenario 4: Disable Transcription Entirely
```bash
ENABLE_TRANSCRIPTION=false
```
- All transcription is disabled
- Manual buttons won't trigger transcription
- Good for importing podcasts without transcription overhead

## UI Features

### Episode Show Page

**Processing Status Card:**
- Shows download status with color-coded badges
- Shows transcription status with color-coded badges
- "Download Audio" button (when not downloaded)
- "Transcribe" button (when not transcribed)
- Buttons hidden when processing is in progress or completed

**Audio Player:**
- Automatically uses local audio if available via `episode.audio_url`
- Falls back to original URL if not downloaded locally

**Transcript Display:**
- Shows transcript text if completed
- Formatted with scrollable container

### Status Badge Colors
- Green (success): completed
- Blue (primary): processing/downloading
- Red (danger): failed
- Gray (secondary): not started

## Future Integration: Ad Detection

The `EpisodeTranscriptionService` is designed to integrate with ad detection:

```ruby
# Step 2: Trim ads if configured (future)
# audio_path = AdTrimmerService.new(episode, audio_path).trim if should_trim_ads?
```

The `AdTrimmerService` will:
1. Take the downloaded audio file
2. Detect ad segments using audio cue fingerprints
3. Create a trimmed version without ads
4. Return path to trimmed audio for transcription
5. Store both original and trimmed versions

## File Storage Structure

```
storage/
├── episodes/
│   ├── {podcast_id}/
│   │   ├── {episode_id}.mp3
│   │   ├── {episode_id}.m4a
│   │   └── ...
└── transcripts/
    ├── {episode_id}.json
    └── ...
```

## API Routes

- `POST /episodes/:id/download_audio` - Trigger audio download
- `POST /episodes/:id/transcribe` - Trigger transcription
- `GET /episodes/:id/audio` - Serve local audio file

## Migration

Migration `20251019193149_add_local_audio_to_episodes.rb` adds:
- local_audio_path (text)
- local_audio_size (integer)
- local_audio_checksum (string)
- download_status (string)

## Testing Checklist

- [ ] Import podcast with AUTO_DOWNLOAD_AUDIO=false
- [ ] Verify episode shows "Not Started" badges
- [ ] Click "Download Audio" button
- [ ] Verify download completes and badge shows "Completed"
- [ ] Verify audio file exists in storage/episodes/{podcast_id}/
- [ ] Click "Transcribe" button
- [ ] Verify transcription completes
- [ ] Verify transcript displays on episode page
- [ ] Verify audio player uses local file when available
- [ ] Test with AUTO_TRANSCRIBE=true and AUTO_DOWNLOAD_AUDIO=true
- [ ] Verify new episodes are automatically processed

## Notes

- Episode model's `after_create` callback checks env vars before enqueueing jobs
- Download service prevents duplicate downloads if file already exists
- Transcription service intelligently chooses between local storage and temp files
- All services include proper error handling and logging
- Local audio URLs are served through Rails controller for future auth/access control
