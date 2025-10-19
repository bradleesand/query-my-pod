# RAG Search Implementation Plan

## Overview

Implement semantic search across podcast transcripts using Retrieval Augmented Generation (RAG). Users can search within a specific podcast or across all podcasts, with results citing specific episodes and timestamps.

## Architecture

### Components

1. **Vector Storage** - SQLite with `neighbor` gem for vector similarity search
2. **Embedding Model** - Local sentence-transformers (Python) for text → vector conversion
3. **LLM** - Local Ollama or llama.cpp for generating responses
4. **Rails Services** - Coordinate embedding, search, and LLM query

### Data Flow

```
User Query: "What did they say about AI?" [Podcast: specific or all]
    ↓
1. Convert query to vector (embedding service)
    ↓
2. Vector search in transcript_chunks (filtered by podcast_id if specified)
    ↓
3. Retrieve top N chunks with metadata:
   - Episode title, podcast name
   - Timestamp (start_time/end_time)
   - Transcript text
    ↓
4. Build context with citations for LLM
    ↓
5. LLM generates response citing episodes/timestamps
    ↓
6. Display to user with deep links to audio at specific times
```

## Database Schema

### New Model: TranscriptChunk

```ruby
# Table: transcript_chunks
- id (integer)
- episode_id (integer, references episodes)
- text (text) - the transcript chunk content
- embedding (binary or text) - vector representation
- start_time (integer) - seconds into episode where chunk starts (null for metadata chunks)
- end_time (integer) - seconds into episode where chunk ends (null for metadata chunks)
- chunk_index (integer) - position in full transcript
- chunk_type (string) - 'transcript', 'title', or 'description' (for future metadata search)
- created_at (datetime)
- updated_at (datetime)

# Indexes:
- episode_id
- start_time
- chunk_type
- Vector index on embedding (if using neighbor gem)
```

**Relationships:**
- `belongs_to :episode`
- `has_one :podcast, through: :episode`

## Implementation Steps

### Phase 1: Transcript Chunking

**Goal:** Split existing transcripts into searchable chunks and store them.

1. **Create TranscriptChunk model and migration**
   - Add table with columns above
   - Add vector column (neighbor gem format)

2. **Create TranscriptChunkingService**
   - Read episode transcript JSON
   - Split into chunks based on:
     - Option A: By segments (using Whisper's segment boundaries)
     - Option B: Fixed time windows (e.g., 30-60 second chunks)
     - Option C: Semantic chunks (sentence/paragraph boundaries)
   - Store chunk text, start_time, end_time, chunk_index
   - Leave embedding null for now

3. **Create rake task to chunk existing transcripts**
   ```ruby
   # rake transcripts:chunk
   Episode.where(transcription_status: :completed).find_each do |episode|
     TranscriptChunkingService.new(episode).chunk
   end
   ```

4. **Update EpisodeTranscriptionService**
   - After transcription completes, automatically chunk the transcript

### Phase 2: Embedding Generation

**Goal:** Generate vector embeddings for all chunks.

1. **Set up embedding service**
   - Install Python dependencies: `sentence-transformers`
   - Create Python script: `scripts/generate_embedding.py`
   - Takes text input, returns vector
   - Model recommendation: `all-MiniLM-L6-v2` (fast, good quality)

2. **Create EmbeddingService (Ruby)**
   - Wraps Python script execution
   - Input: text string
   - Output: vector array
   - Cache/batch processing for efficiency

3. **Create rake task to generate embeddings**
   ```ruby
   # rake transcripts:generate_embeddings
   TranscriptChunk.where(embedding: nil).find_each do |chunk|
     embedding = EmbeddingService.new.generate(chunk.text)
     chunk.update!(embedding: embedding)
   end
   ```

4. **Update TranscriptChunkingService**
   - After creating chunks, generate embeddings automatically
   - Or queue as background job for large transcripts

### Phase 3: Vector Search

**Goal:** Search chunks by semantic similarity.

1. **Install neighbor gem**
   ```ruby
   gem 'neighbor'
   ```

2. **Configure TranscriptChunk model for vector search**
   ```ruby
   class TranscriptChunk < ApplicationRecord
     belongs_to :episode
     has_one :podcast, through: :episode
     
     has_neighbors :embedding
   end
   ```

3. **Create TranscriptSearchService**
   - Input: query string, optional podcast_id
   - Convert query to embedding
   - Search for nearest neighbors
   - Return ranked chunks with metadata
   
   ```ruby
   class TranscriptSearchService
     def search(query, podcast_id: nil, limit: 10)
       query_embedding = EmbeddingService.new.generate(query)
       
       chunks = TranscriptChunk.includes(:episode, :podcast)
       chunks = chunks.joins(:episode).where(episodes: { podcast_id: podcast_id }) if podcast_id
       
       chunks.nearest_neighbors(:embedding, query_embedding, distance: "cosine")
             .limit(limit)
             .map { |chunk| format_result(chunk) }
     end
   end
   ```

### Phase 4: LLM Integration

**Goal:** Use LLM to generate natural language responses with citations.

1. **Set up local LLM**
   - Install Ollama: `https://ollama.ai`
   - Pull model: `ollama pull llama3.2` (or similar)
   - Start server: `ollama serve`

2. **Create LlmQueryService**
   - Input: query, context chunks
   - Build prompt with context and instruction to cite sources
   - Call Ollama API
   - Parse and return response
   
   ```ruby
   class LlmQueryService
     def query(question, chunks)
       context = build_context(chunks)
       prompt = build_prompt(question, context)
       
       response = call_ollama(prompt)
       parse_response(response)
     end
     
     private
     
     def build_context(chunks)
       chunks.map.with_index do |chunk, i|
         "[Source #{i+1}] Episode: #{chunk.episode.title} (#{format_time(chunk.start_time)})\n#{chunk.text}"
       end.join("\n\n")
     end
     
     def build_prompt(question, context)
       <<~PROMPT
         You are a helpful assistant that answers questions about podcast transcripts.
         
         Context (cite these sources in your answer):
         #{context}
         
         Question: #{question}
         
         Answer the question based only on the provided context. Cite your sources using the episode name and timestamp (e.g., "In episode 'AI Deep Dive' at 15:32...").
       PROMPT
     end
   end
   ```

3. **Handle API calls**
   - Use HTTParty or similar gem
   - POST to `http://localhost:11434/api/generate`
   - Handle streaming responses (optional)

### Phase 5: UI and Controller

**Goal:** Expose search interface to users.

1. **Create SearchController**
   ```ruby
   class SearchController < ApplicationController
     def index
       # Show search form
     end
     
     def query
       @query = params[:query]
       @podcast_id = params[:podcast_id]
       
       # Get relevant chunks
       chunks = TranscriptSearchService.new.search(@query, podcast_id: @podcast_id)
       
       # Generate LLM response
       @response = LlmQueryService.new.query(@query, chunks)
       @sources = chunks
       
       render :results
     end
   end
   ```

2. **Create search views**
   - `search/index.html.erb` - Search form with podcast selector
   - `search/results.html.erb` - Display LLM response with cited sources
   - Each source links to episode page with timestamp anchor

3. **Add routes**
   ```ruby
   get '/search', to: 'search#index'
   post '/search/query', to: 'search#query'
   ```

4. **Enhance episode player**
   - Support deep linking with timestamps: `/episodes/123?t=920` (15:20)
   - Auto-seek audio player to timestamp

### Phase 6: Background Jobs

**Goal:** Process transcripts asynchronously.

1. **Create GenerateEmbeddingsJob**
   - Enqueued after transcription completes
   - Chunks transcript and generates embeddings
   
2. **Update EpisodeTranscriptionService**
   - Queue GenerateEmbeddingsJob after successful transcription

## Technical Decisions

### Chunking Strategy

**Recommendation: Use Whisper segments**
- Whisper already provides natural speech boundaries
- Each segment has start/end timestamps
- Segment length is reasonable (few seconds to ~30 seconds)
- Alternative: Combine multiple segments for larger chunks (~60 seconds)

### Embedding Model

**Recommendation: all-MiniLM-L6-v2**
- Fast inference (~300ms for batch of 32)
- 384 dimensions (smaller than alternatives)
- Good quality for semantic search
- Widely used and tested
- Alternative: `all-mpnet-base-v2` (higher quality, slower)

### LLM Model

**Recommendation: Llama 3.2 or Mistral**
- Good instruction following
- Handles citations well
- Fast on consumer hardware
- ~3B-8B params for speed vs. quality balance

### Vector Storage

**Using neighbor gem with SQLite:**
- Pure Ruby implementation
- No native extensions needed
- Good for small-to-medium datasets (<100k chunks)
- Cosine distance for similarity

**Future: Consider pgvector if moving to PostgreSQL**

## Environment Variables

```bash
# Enable semantic search feature
ENABLE_SEMANTIC_SEARCH=true

# Python path for embedding script
PYTHON_PATH=/usr/bin/python3

# Ollama API endpoint
OLLAMA_API_URL=http://localhost:11434

# Ollama model name
OLLAMA_MODEL=llama3.2

# Number of chunks to retrieve for context
SEARCH_CONTEXT_CHUNKS=5

# Embedding model name
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
```

## Testing Strategy

1. **Unit tests**
   - TranscriptChunkingService: verify chunking logic
   - EmbeddingService: mock Python calls
   - TranscriptSearchService: test filtering and ranking
   - LlmQueryService: mock API responses

2. **Integration tests**
   - End-to-end search flow
   - Test with sample transcripts
   - Verify citations are accurate

3. **Manual testing**
   - Search for known topics
   - Verify episode/timestamp accuracy
   - Test podcast scoping

## Future Enhancements

### Episode Metadata Search
- **Include titles/descriptions**: Create separate chunks for episode titles and descriptions
- **Metadata weighting**: Boost relevance scores for transcript chunks from episodes with matching titles/descriptions
  - Example: If query matches episode title, multiply chunk scores from that episode by 1.5x
  - If query matches description, multiply by 1.25x
- **Implementation approach**:
  - Store episode title/description as special chunks (chunk_type: 'metadata')
  - When retrieving results, check if any metadata chunks match
  - Rerank transcript chunks based on their episode's metadata relevance

### Other Enhancements
- **Hybrid search**: Combine vector search with keyword search (BM25)
- **Query refinement**: Suggest related searches
- **Conversation history**: Multi-turn conversations with context
- **Summarization**: Generate episode summaries
- **Topic extraction**: Identify main themes per episode
- **Speaker attribution**: If using diarization, attribute quotes to speakers
- **Cross-episode analysis**: "Compare what they said about X in episode A vs B"
- **Temporal search**: "What did they say about X this month vs last year?"

## Dependencies

### Ruby Gems
- `neighbor` - Vector similarity search
- `httparty` - HTTP client for Ollama API (or use built-in Net::HTTP)

### Python Packages
```bash
pip install sentence-transformers torch
```

### System Requirements
- Python 3.8+
- Ollama (or alternative local LLM)
- ~2-4GB RAM for embedding model
- ~4-8GB RAM for LLM (depending on model size)

## Migration Path to Production

When ready for production scale:

1. **Switch to PostgreSQL + pgvector**
   - More efficient vector operations
   - Better indexing (HNSW, IVFFlat)
   - Handles millions of vectors

2. **Consider dedicated vector DB**
   - Qdrant, Milvus, or Weaviate
   - Only if SQLite/PostgreSQL performance inadequate

3. **Use hosted embedding API**
   - OpenAI embeddings
   - Cohere embeddings
   - Faster, no Python dependency

4. **Use hosted LLM API**
   - OpenAI GPT-4
   - Anthropic Claude
   - Better quality, no local hardware requirements

## Timeline Estimate

- **Phase 1 (Chunking)**: 4-6 hours
- **Phase 2 (Embeddings)**: 4-6 hours  
- **Phase 3 (Search)**: 3-4 hours
- **Phase 4 (LLM)**: 4-6 hours
- **Phase 5 (UI)**: 3-4 hours
- **Phase 6 (Jobs)**: 2-3 hours

**Total: ~20-30 hours** for basic working prototype

## Success Metrics

- Can search transcripts and get relevant results
- LLM responses cite correct episodes and timestamps
- Deep links navigate to correct audio position
- Search scoped by podcast works correctly
- Processing completes within reasonable time (<5min per hour of audio)
