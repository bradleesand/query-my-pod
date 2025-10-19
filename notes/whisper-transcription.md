# Whisper Transcription Setup

## Installation

Install OpenAI Whisper:

```bash
pip install openai-whisper
```

Or with conda:

```bash
conda install -c conda-forge openai-whisper
```

## Usage

### Manual Transcription

To manually transcribe an episode:

```ruby
EpisodeProcessingJob.perform_later(episode_id, [:transcribe])
```

### Batch Transcription

To transcribe all episodes without transcripts:

```ruby
Episode.where(transcription_status: [nil, "failed"]).find_each do |episode|
  EpisodeProcessingJob.perform_later(episode.id, [:transcribe])
end
```

## Storage

Transcripts are stored as JSON files in:
- `storage/transcripts/{episode_id}.json`

Access via model methods:
```ruby
episode.transcript_content  # Returns parsed JSON with full data
episode.transcript_text     # Returns just the text content
episode.transcript_file_path  # Returns file path
```

### JSON Structure

The JSON output includes:
```json
{
  "text": "Full transcript text...",
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 3.5,
      "text": "Segment text...",
      "tokens": [...],
      "temperature": 0.0,
      "avg_logprob": -0.3,
      "compression_ratio": 1.5,
      "no_speech_prob": 0.01
    }
  ],
  "language": "en"
}
```

## Status Tracking

Episode `transcription_status` enum:
- `pending` - Not yet transcribed
- `processing` - Currently transcribing
- `completed` - Successfully transcribed
- `failed` - Transcription failed

## Models

Whisper has several models with different sizes and performance:
- `tiny` - Fastest, least accurate
- `base` - Good balance (currently configured)
- `small` - Better accuracy
- `medium` - High accuracy
- `large` - Best accuracy, slowest

Change model in the `EpisodeTranscriptionService`:
```ruby
whisper "#{audio_file_path}" --model small ...
```

## Future Improvements

- Consider using OpenAI API for transcription instead of local Whisper
- Add support for different languages
- Store transcripts in a vector database for semantic search
- Generate embeddings for RAG (Retrieval Augmented Generation)
- Add UI to trigger transcription from episode page
