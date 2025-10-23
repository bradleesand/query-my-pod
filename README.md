# Podcast Search

A self-hosted web application that makes your favorite podcasts searchable and queryable through AI. Track podcasts via RSS, automatically transcribe episodes, and use semantic search with local LLMs to discover content across your entire podcast library.

## ⚠️ Project Status

**Production Ready!** All core features are implemented and working. The application provides full RAG-powered semantic search with interactive transcript playback.

## Features

### ✅ Implemented

#### Podcast Management
- **RSS Feed Management**: Subscribe to podcasts via RSS with automatic episode discovery
- **Episode Import**: Extracts metadata, cover art, and audio following PSP-1 spec
- **Daily Refresh**: Automatically checks for new episodes
- **Background Jobs**: Solid Queue handles imports, transcription, and scheduled tasks

#### Transcription & Processing
- **Automatic Transcription**: Self-hosted Whisper generates timestamped JSON transcripts
- **Transcript Chunking**: Automatically segments transcripts into searchable chunks
- **Vector Embeddings**: Generates semantic embeddings using sentence-transformers
- **Ad Detection**: LLM-powered advertisement detection with confidence scores
- **Flexible Pipeline**: Composable processing steps (download → transcribe → chunk → detect ads → embed)

#### AI-Powered Search
- **Semantic Search**: Vector similarity search using SQLite with neighbor gem
- **RAG (Retrieval Augmented Generation)**: LLM generates answers with citations
- **Local LLM Integration**: Works with Ollama (qwen2.5:7b, llama3.2, etc.)
- **LLM Tool Calling**: AI can request additional context when needed (up to 3 iterations)
- **Weighted Search Results**: Title matches boosted 3x, descriptions 2x for better relevance
- **Context-Aware Search**: Search within episode, podcast, or across all podcasts
- **Inline Search Results**: Turbo-powered search with loading indicators
- **CLI Query Tool**: Command-line interface for querying transcripts

#### Interactive Transcript Player
- **Live Transcript Highlighting**: Synchronized with audio playback
- **Click-to-Seek**: Click any transcript chunk to jump to that timestamp
- **Search Result Navigation**: Click search results to jump directly to relevant audio
- **HTTP Range Requests**: Efficient audio seeking without buffering entire file
- **Dual Highlight Modes**: Different styles for navigation vs playback tracking
- **Smart Scrolling**: Auto-scroll transcript without interfering with page navigation

#### User Interface
- **Web Interface**: Modern Bootstrap 5 UI with Hotwire/Turbo
- **Audio Player**: HTML5 player with timestamp deep linking
- **Search UI**: Contextual search boxes embedded in relevant pages
- **Responsive Design**: Works on desktop and mobile

### 📋 Potential Future Enhancements

- **Advanced Search Features**: Filter by date, podcast, keywords
- **Search History**: Track and revisit previous searches
- **Saved Searches**: Bookmark frequently used queries
- **Episode Cross-Linking**: Discover related episodes and topics
- **Speaker Diarization**: Identify different speakers in episodes
- **Multi-Language Support**: Transcribe and search non-English podcasts
- **Export Features**: Export transcripts, search results, or citations
- **API Access**: RESTful API for programmatic access
- **Docker Deployment**: One-command deployment with Docker Compose

## Use Cases

- Find specific discussions or topics across hundreds of episodes
- Research what multiple podcasts have said about a particular subject
- Build a personal, searchable podcast knowledge base
- Discover connections between episodes and topics
- Jump directly to relevant moments in podcast episodes
- Follow along with transcripts synchronized to audio playback

## Tech Stack

- **Backend**: Ruby on Rails 8
- **Database**: SQLite with vector search (neighbor + sqlite-vec)
- **Background Jobs**: Solid Queue
- **Transcription**: Whisper (self-hosted)
- **Embeddings**: sentence-transformers (all-MiniLM-L6-v2)
- **LLM**: Ollama (qwen2.5:7b, llama3.2, or similar)
- **Vector Search**: neighbor gem with cosine similarity
- **UI**: Bootstrap 5 with Hotwire/Turbo + Stimulus
- **Audio**: HTML5 with HTTP range request support

## Prerequisites

- Ruby 3.4+
- Rails 8
- Python 3.8+ with virtual environment
- [Whisper](https://github.com/openai/whisper): `pip install openai-whisper`
- [Ollama](https://ollama.ai): For LLM functionality
- Sufficient storage for podcast audio files, transcripts, and embeddings
- GPU recommended (but not required) for faster transcription

## Installation

```bash
# Clone the repository
git clone https://gitlab.com/bradleesand/podcast-search.git
cd podcast-search

# Install Ruby dependencies
bundle install

# Setup database
rails db:setup

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install Python dependencies
pip install openai-whisper sentence-transformers torch

# Install and start Ollama
brew install ollama  # On macOS
ollama serve &
ollama pull qwen2.5:7b  # Or llama3.2, gemma3:12b, etc.

# Run the application (with background jobs)
bin/dev
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Episode Processing Configuration
AUTO_TRANSCRIBE=false          # Auto-transcribe new episodes
ENABLE_TRANSCRIPTION=true      # Enable transcription feature
AUTO_DOWNLOAD_AUDIO=false      # Auto-download audio for new episodes
DOWNLOAD_AUDIO=false           # Keep audio files after transcription

# RAG Search Configuration
ENABLE_SEMANTIC_SEARCH=true    # Enable vector search and LLM features
PYTHON_PATH=venv/bin/python3   # Path to Python in virtual environment
OLLAMA_API_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5:7b        # LLM model (qwen2.5:7b recommended)
SEARCH_CONTEXT_CHUNKS=5        # Number of chunks for context

# Ad Detection Configuration
ENABLE_AD_DETECTION=false      # Enable automatic ad detection
AD_DETECTION_THRESHOLD=0.7     # Confidence threshold (0.0-1.0) for marking as ad
```

**Recommended Configuration for Full Features:**
```bash
AUTO_TRANSCRIBE=true
ENABLE_SEMANTIC_SEARCH=true
DOWNLOAD_AUDIO=true  # If you want to keep audio files
```

### OpenSSL 3.6.0 Compatibility

If you encounter SSL certificate verification errors with OpenSSL 3.6.0, the `openssl` gem is included in the Gemfile.

### Recurring Jobs

Daily podcast refresh is configured in `config/recurring.yml` and runs at 2am by default. Edit this file to change the schedule.

## Usage

### Getting Started

1. **Import a podcast**: Click "Import New Podcast" and paste an RSS feed URL
2. **View podcasts**: Browse your podcast library on the home page
3. **View episodes**: Click a podcast to see all episodes
4. **Process episodes**:
   - Automatic: Set `AUTO_TRANSCRIBE=true` for new episodes
   - Manual: Use "Download Audio" and "Transcribe" buttons on episode pages

### Using Search

1. **Search from anywhere**:
   - Podcast index: Search across all podcasts
   - Podcast page: Search within that podcast
   - Episode page: Search within that episode

2. **View results**:
   - AI-generated answer with citations
   - Source excerpts with similarity scores
   - Clickable links to episodes with timestamp

3. **Interactive transcript**:
   - Click search results to jump to exact moment
   - Click transcript chunks to seek audio
   - Watch live highlighting as audio plays

### Processing Existing Episodes

If you have existing episodes and want to enable search:

```bash
# Chunk and generate embeddings for all transcribed episodes
rails transcripts:chunk
rails transcripts:generate_embeddings

# Or process a single episode
rails runner "EpisodeProcessingJob.perform_now(episode_id, [:chunk_transcript, :generate_embeddings])"
```

See the [Rake Tasks](#rake-tasks) section below for more batch processing options.

### Ad Detection

Detect advertisements in transcripts using LLM analysis:

```bash
# Detect ads in all transcribed episodes
rails ads:detect_all

# Detect ads in a specific episode
rails ads:detect_episode[EPISODE_ID]

# Review detected advertisements
rails ads:review

# Show detection statistics by podcast
rails ads:stats

# Reset ad detection for an episode
rails ads:reset_episode[EPISODE_ID]
```

**How it works:**
- Uses your local LLM (Ollama) to analyze transcript chunks
- Identifies sponsor mentions, promo codes, and promotional content
- Stores confidence scores (0.0-1.0) for each chunk
- Advertisements are excluded from search results by default
- Ad chunks are styled differently in the transcript view (gray, italic)

### CLI Query Tool

Query your podcast transcripts directly from the command line:

```bash
# Basic query across all podcasts
rails runner scripts/query_llm.rb "What are some productivity tips?"

# Query with verbose output (shows all sources and similarity scores)
rails runner scripts/query_llm.rb "What productivity apps were mentioned?" --verbose

# Query specific podcast
rails runner scripts/query_llm.rb "What did they say about focus?" --context podcast --podcast 1

# Query specific episode
rails runner scripts/query_llm.rb "What was the main topic?" --context episode --episode 123

# Filter by listened status
rails runner scripts/query_llm.rb "What are the main themes?" --filter unlistened

# Adjust context chunks (more context = better answers, slower response)
rails runner scripts/query_llm.rb "Tell me about the guest" --limit 15

# Combined options
rails runner scripts/query_llm.rb "What tools were recommended?" \
  --context podcast \
  --podcast 1 \
  --filter listened \
  --limit 12 \
  --verbose
```

**Available Options:**
- `-c, --context CONTEXT` - Search context: `all`, `podcast`, `episode` (default: all)
- `-p, --podcast ID` - Podcast ID (required for podcast/episode context)
- `-e, --episode ID` - Episode ID (required for episode context)
- `-l, --limit N` - Number of initial context chunks (default: 10)
- `-f, --filter FILTER` - Listened filter: `all`, `listened`, `unlistened`
- `-v, --verbose` - Show detailed sources with similarity scores
- `-h, --help` - Show help message

**How it works:**
- Performs semantic vector search across transcript chunks
- LLM can automatically request additional context via tool calling (up to 3 iterations)
- Returns AI-generated answer with numbered citations
- Verbose mode shows all sources with episode info, timestamps, and similarity scores
- Respects same filtering and scoping as web search

## Rake Tasks

### Transcript Management

**Chunk transcripts into searchable segments:**
```bash
rails transcripts:chunk
```
Processes all episodes with completed transcripts and splits them into searchable chunks. Creates one `TranscriptChunk` per Whisper segment with text and timestamps.

**Generate embeddings for semantic search:**
```bash
rails transcripts:generate_embeddings
```
Generates 384-dimensional vector embeddings for all transcript chunks that don't have embeddings yet. Uses sentence-transformers (all-MiniLM-L6-v2 model) via Python. Required for semantic search functionality.

### Advertisement Detection

**Detect ads in all episodes:**
```bash
rails ads:detect_all
```
Analyzes all transcribed episodes to detect advertisements using your local LLM. Skips episodes that have already been analyzed. Shows progress and summary statistics.

**Detect ads in a specific episode:**
```bash
rails ads:detect_episode[EPISODE_ID]
```
Analyzes a single episode and displays detected advertisement chunks with confidence scores and timestamps.

Example: `rails ads:detect_episode[42]`

**Review detected advertisements:**
```bash
rails ads:review
```
Shows a detailed review of all detected advertisements across all episodes, grouped by episode with timestamps and confidence scores.

**Show detection statistics:**
```bash
rails ads:stats
```
Displays advertisement detection statistics including:
- Overall ad detection rate
- Analysis coverage (analyzed vs unanalyzed chunks)
- Per-podcast statistics and ad rates

**Reset ad detection for an episode:**
```bash
rails ads:reset_episode[EPISODE_ID]
```
Clears all advertisement detection data for a specific episode, allowing you to re-run detection with different settings or after adjusting the LLM model.

Example: `rails ads:reset_episode[42]`

### Model Annotations

**Annotate models with schema info:**
```bash
rails annotate_models
```
Adds schema information as comments to model files and fixtures. Automatically runs after migrations.

**Remove annotations:**
```bash
rails remove_annotation
```
Removes schema annotation comments from model and fixture files.

## Architecture

### Processing Pipeline

Episodes are processed through a flexible pipeline system via `EpisodeProcessingJob`. The job accepts a list of steps to execute in sequence:

**Available Steps:**
- `:download` - Download audio to local storage
- `:trim_ads` - Remove ads using audio cue detection (experimental, not yet implemented)
- `:transcribe` - Generate transcript with Whisper
- `:chunk_transcript` - Split transcript into searchable segments
- `:detect_ads_in_transcript` - Detect advertisements using LLM analysis
- `:generate_embeddings` - Create vector embeddings for semantic search

**Example Pipelines:**
```ruby
# Full RAG pipeline (when ENABLE_SEMANTIC_SEARCH=true)
EpisodeProcessingJob.perform_later(episode_id, [:download, :transcribe, :chunk_transcript, :generate_embeddings])

# Just transcription
EpisodeProcessingJob.perform_later(episode_id, [:transcribe])

# Add search to existing transcript
EpisodeProcessingJob.perform_later(episode_id, [:chunk_transcript, :generate_embeddings])

# Transcribe without search features
EpisodeProcessingJob.perform_later(episode_id, [:transcribe])
```

**Automatic Pipeline** (when `AUTO_TRANSCRIBE=true` and `ENABLE_SEMANTIC_SEARCH=true`):
```ruby
[:download, :transcribe, :chunk_transcript, :generate_embeddings]
```

### RAG Architecture

**Data Flow:**
1. **Transcription**: Whisper generates timestamped transcripts
2. **Chunking**: TranscriptChunkingService splits by Whisper segments and creates title/description chunks
3. **Embedding**: Python sentence-transformers creates 384-dim vectors
4. **Storage**: SQLite stores chunks with vector embeddings
5. **Search**: neighbor gem performs cosine similarity search with weighted ranking
6. **LLM**: Ollama generates cited responses using top chunks
7. **Tool Calling** (optional): LLM can request additional context via search_transcript tool (up to 3 iterations)

**Key Features:**
- **Weighted Ranking**: Title chunks boosted 3x, description chunks 2x, transcript chunks 1x
- **Tool Calling**: LLM can autonomously gather more context when initial results are insufficient
- **Iterative Refinement**: Up to 3 tool call iterations prevent infinite loops
- **Metadata Search**: Episode titles and descriptions included as searchable chunks

**Key Components:**
- `TranscriptChunk` model: Stores text chunks with embeddings, timestamps, and chunk type (title/description/transcript/advertisement)
- `TranscriptSearchService`: Performs vector similarity search with weighted re-ranking
- `EmbeddingService`: Wraps Python script for embedding generation
- `LlmQueryService`: Queries Ollama with context, supports tool calling for iterative search
- `SearchController`: Handles search UI and Turbo Frame rendering

### Service Architecture

**Processing Pipeline:**
- `EpisodeProcessingJob`: Orchestrates multi-step processing
- `TranscriptChunkingService`: Chunks transcripts into segments
- `EmbeddingService`: Generates vector embeddings

**Core Services:**
- `PodcastImportService`: Handles initial RSS import
- `PodcastRssSyncService`: Refreshes podcasts with new episodes
- `EpisodeAudioDownloadService`: Downloads audio files
- `EpisodeTranscriptionService`: Orchestrates transcription
- `TranscriptSearchService`: Semantic search across chunks
- `LlmQueryService`: LLM response generation

**Background Jobs:**
- `EpisodeProcessingJob`: Pipeline orchestrator
- `PodcastRefreshJob`: Refreshes a single podcast
- `RefreshAllPodcastsJob`: Daily refresh of all podcasts

## Development Roadmap

- [x] Basic Rails application structure
- [x] RSS feed ingestion and episode import
- [x] Whisper integration for transcription
- [x] Database schema for podcasts and episodes
- [x] Background job processing with Solid Queue
- [x] Web UI for podcast management
- [x] Daily automatic refresh of feeds
- [x] Display transcripts in episode UI
- [x] Vector embeddings for semantic search
- [x] LLM chat interface with RAG
- [x] Search and indexing functionality
- [x] Interactive transcript with audio synchronization
- [x] HTTP range requests for efficient seeking
- [x] LLM-based advertisement detection in transcripts
- [ ] Enhanced search UI (filters, history, saved searches)
- [ ] pyannote-audio integration for speaker diarization
- [ ] Episode cross-linking and recommendations
- [ ] Audio-based ad trimming (fingerprinting approach)
- [ ] Docker deployment configuration
- [ ] API access layer

## Performance Considerations

### Storage Requirements
- **Audio**: ~50-100MB per hour (if `DOWNLOAD_AUDIO=true`)
- **Transcripts**: ~5-10KB per hour (JSON format)
- **Embeddings**: ~1.5KB per chunk × ~60 chunks/hour = ~90KB per hour
- **Total**: ~50-100MB per hour with audio, ~100KB without

### Processing Time (CPU-based, no GPU)
- **Transcription**: ~10-15 minutes per hour of audio
- **Chunking**: Seconds
- **Embeddings**: ~1-2 seconds per chunk (first run slower due to model loading)
- **Search**: Milliseconds for vector search, 2-5 seconds for LLM response

### Optimization Tips
- Use GPU for faster transcription (3-5x speedup)
- Batch embedding generation for new podcasts
- Increase `SEARCH_CONTEXT_CHUNKS` for better context (slower LLM response)
- Use faster LLM models like llama3.2 (less accurate but 2x faster)

## Contributing

This is a personal project in active development. Contributions, ideas, and feedback are welcome!

## License

[License TBD]

## Acknowledgments

- [Whisper](https://github.com/openai/whisper) - Speech recognition
- [Ollama](https://ollama.ai) - Local LLM hosting
- [sentence-transformers](https://www.sbert.net/) - Text embeddings
- [neighbor](https://github.com/ankane/neighbor) - Vector similarity search
- [PSP-1 Podcast RSS Specification](https://github.com/Podcast-Standards-Project/PSP-1-Podcast-RSS-Specification)

---

**Self-hosted. Private. Searchable.**