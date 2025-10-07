# Podcast Search

A self-hosted web application that makes your favorite podcasts searchable and queryable through AI. Track podcasts via RSS, automatically transcribe episodes, and chat with an LLM to discover content across your entire podcast library.

## ⚠️ Project Status

This project is in early development. Features and documentation will evolve as the project matures.

## Features (Planned)

- **RSS Feed Management**: Add and track podcasts via RSS feeds
- **Automatic Transcription**: Self-hosted transcription using Whisper
- **Speaker Diarization**: Identify and label different speakers using pyannote-audio
- **AI-Powered Search**: Query your podcast library with natural language questions
  - "Which episode did they talk about X?"
  - Find topics and discussions across all episodes
- **Episode Cross-Linking**: Discover related episodes and topics
- **Full Transcript Access**: Browse and read complete episode transcripts
- **Ad Detection** (Experimental): Automatic identification and trimming of ad segments

## Use Cases

- Find specific discussions or topics across hundreds of episodes
- Research what multiple podcasts have said about a particular subject
- Build a personal, searchable podcast knowledge base
- Discover connections between episodes and topics

## Tech Stack

- **Backend**: Ruby on Rails
- **Transcription**: Whisper (self-hosted)
- **Speaker Diarization**: pyannote-audio
- **LLM**: Qwen (or similar self-hosted model)
- **Deployment**: Docker

## Prerequisites

- Docker and Docker Compose
- Sufficient storage for podcast audio files and transcripts
- GPU recommended (but not required) for faster transcription

## Installation

> **Note**: Installation instructions will be added as the project develops.

```bash
# Clone the repository
git clone https://gitlab.com/bradleesand/podcast-search.git
cd podcast-search

# Build and run with Docker
docker-compose up
```

## Configuration

Configuration details will be documented as features are implemented.

## Usage

1. Add podcast RSS feeds through the web interface
2. The system automatically downloads new episodes
3. Episodes are transcribed and indexed
4. Use the chat interface to query your podcast library
5. Browse transcripts with cross-links to related episodes

## Development Roadmap

- [ ] Basic Rails application structure
- [ ] RSS feed ingestion and episode downloading
- [ ] Whisper integration for transcription
- [ ] pyannote-audio integration for speaker diarization
- [ ] Database schema for episodes, transcripts, and topics
- [ ] LLM chat interface
- [ ] Search and indexing functionality
- [ ] Episode cross-linking
- [ ] Ad detection and trimming (experimental)
- [ ] Docker deployment configuration
- [ ] Web UI for podcast management

## Architecture

The application follows this workflow:

1. **Ingestion**: RSS feeds are polled for new episodes
2. **Download**: Audio files are downloaded and stored
3. **Pre-processing**: (Optional) Ad detection and removal
4. **Transcription**: Whisper generates text transcripts
5. **Diarization**: Speaker segments are identified and labeled
6. **Indexing**: Topics and content are extracted and indexed
7. **Query**: LLM enables natural language search and discovery

## Contributing

This is a personal project in early development. Contributions, ideas, and feedback are welcome as the project takes shape.

## License

[License TBD]

## Acknowledgments

- [Whisper](https://github.com/openai/whisper) - Speech recognition
- [pyannote-audio](https://github.com/pyannote/pyannote-audio) - Speaker diarization
- [Qwen](https://github.com/QwenLM/Qwen) - LLM capabilities

## Contact

[Your contact information]

---

**Self-hosted. Private. Searchable.**