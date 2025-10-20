# Next Phase: Advanced Features

## Priority 1: Speaker Diarization

### Goal
Identify and label different speakers in podcast episodes, showing who is speaking in the transcript.

### Tasks
1. **Setup pyannote-audio**
   - Install pyannote dependencies in Python venv
   - Accept HuggingFace license for speaker-diarization-3.1 model
   - Create SpeakerDiarizationService to wrap Python script
   - Add `:identify_speakers` step to EpisodeProcessingJob

2. **Database Schema**
   - Add `speaker_label` column to transcript_chunks
   - Consider separate Speaker model with name mapping
   - Migration to add speaker tracking

3. **Integration**
   - Update TranscriptChunkingService to include speaker info
   - Merge speaker boundaries with Whisper segments
   - Handle speaker changes mid-segment

4. **UI Updates**
   - Display speaker labels in transcript view
   - Color-code or style different speakers
   - Speaker legend/key
   - Option to filter/search by speaker

### Technical Considerations
- pyannote-audio requires GPU or will be slow (30-60min per hour of audio)
- Speaker labels are numeric (Speaker 0, 1, 2) - may want manual naming
- Works best with 2-5 speakers; struggles with large groups
- May need to batch process existing episodes

### Estimated Time: 8-12 hours

---

## Priority 2: Ad Detection & Trimming

### Goal
Automatically detect and remove advertisements from podcast audio before transcription.

### Approaches

#### Option A: Audio Fingerprinting (Recommended)
Use pre-roll/post-roll ad detection by fingerprinting common ad segments.

**Tasks:**
1. Create AdDetectionService using aubio or chromaprint
2. Build database of known ad fingerprints
3. Detect repeating segments across episodes
4. Add `:detect_ads` and `:trim_ads` pipeline steps
5. Store ad boundaries in database for review

**Pros:** Most accurate for common ads
**Cons:** Requires building ad database, misses dynamic ads

#### Option B: Silence Detection
Detect ads by unusual silence patterns or volume changes.

**Tasks:**
1. Use ffmpeg silence detection
2. Analyze patterns around silence
3. Heuristics for ad boundaries

**Pros:** Simpler, works for many podcasts
**Cons:** Less accurate, many false positives

#### Option C: Transcript Analysis (Post-processing)
Use LLM to identify ad content in transcripts.

**Tasks:**
1. Analyze transcript chunks for ad patterns
2. Mark chunks as ads vs content
3. Exclude ad chunks from search
4. Optional: re-encode audio without ads

**Pros:** Works with existing transcripts, uses LLM
**Cons:** Ads still in audio, processing after transcription

### Recommended Approach
Start with Option C (transcript analysis) as it:
- Works with existing pipeline
- Doesn't require re-downloading audio
- Uses existing LLM infrastructure
- Can filter ads from search results immediately

Then add Option A (fingerprinting) for better accuracy.

### Tasks (Option C - Transcript Analysis)
1. Create AdDetectionService using LLM
2. Add `is_advertisement` boolean to transcript_chunks
3. Create rake task to analyze existing chunks
4. Update TranscriptSearchService to exclude ads
5. Add UI toggle to show/hide ads in transcript
6. Add `:detect_ads_in_transcript` pipeline step

### Estimated Time: 6-10 hours

---

## Priority 3: Docker Deployment

### Goal
Package application with all dependencies for one-command deployment.

### Tasks

1. **Create Dockerfiles**
   - Main Rails app Dockerfile
   - Python services container
   - Ollama container (or use official image)

2. **Docker Compose**
   - Rails app service
   - Python worker service
   - Ollama service
   - SQLite volume mounts
   - Storage volume mounts
   - Environment configuration

3. **Optimize Build**
   - Multi-stage builds to reduce image size
   - Cache Python dependencies
   - Pre-download Whisper and sentence-transformers models
   - Pre-pull Ollama model

4. **Documentation**
   - Update README with Docker instructions
   - Environment variable documentation
   - Volume management guide
   - GPU passthrough instructions (for transcription)

5. **Testing**
   - Test full pipeline in Docker
   - Verify all services communicate
   - Test data persistence
   - Performance benchmarks

### Docker Compose Structure
```yaml
services:
  web:
    build: .
    volumes:
      - ./storage:/rails/storage
      - sqlite_data:/rails/db
    environment:
      - OLLAMA_API_URL=http://ollama:11434
      - PYTHON_PATH=/usr/bin/python3
    depends_on:
      - ollama
      - python_worker

  python_worker:
    build:
      context: .
      dockerfile: Dockerfile.python
    volumes:
      - ./storage:/rails/storage
      - models:/models

  ollama:
    image: ollama/ollama:latest
    volumes:
      - ollama_data:/root/.ollama
    # Optional GPU support
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1
    #           capabilities: [gpu]

volumes:
  sqlite_data:
  ollama_data:
  models:
```

### Estimated Time: 6-8 hours

---

## Priority 4: Topic & Entity Extraction

### Goal
Identify recurring topics, people, and events across episodes to enable cross-referencing.

### Architecture

#### Database Schema
```ruby
# Topics (concepts, subjects)
create_table :topics do |t|
  t.string :name, null: false, index: true
  t.text :description
  t.string :topic_type # person, place, event, concept, organization
  t.integer :mention_count, default: 0
  t.timestamps
end

# Topic mentions in chunks
create_table :topic_mentions do |t|
  t.references :topic, null: false, foreign_key: true
  t.references :transcript_chunk, null: false, foreign_key: true
  t.references :episode, null: false, foreign_key: true
  t.float :relevance_score # 0-1, how relevant the mention is
  t.text :context # surrounding text
  t.timestamps
end

# Topic relationships (e.g., "Trump" related to "Republican Party")
create_table :topic_relationships do |t|
  t.references :topic_a, null: false, foreign_key: { to_table: :topics }
  t.references :topic_b, null: false, foreign_key: { to_table: :topics }
  t.string :relationship_type # "related_to", "part_of", "opposite_of"
  t.float :strength # 0-1
  t.timestamps
end
```

#### Implementation Approaches

**Option A: NER (Named Entity Recognition)**
Use spaCy or similar for entity extraction.

**Tasks:**
1. Install spaCy with en_core_web_lg model
2. Create EntityExtractionService
3. Extract PERSON, ORG, GPE, EVENT entities
4. Link entities to Topics
5. Track mention frequency

**Pros:** Fast, accurate for names/places
**Cons:** Misses abstract concepts, requires training for domain-specific entities

**Option B: LLM-Based Extraction**
Use Ollama to identify topics and entities.

**Tasks:**
1. Create TopicExtractionService using LLM
2. Prompt LLM to identify key topics/entities per chunk
3. Aggregate and deduplicate across episodes
4. Build topic index with descriptions

**Pros:** Finds abstract topics, contextual understanding
**Cons:** Slower, API costs (mitigated by local LLM)

**Option C: Hybrid Approach (Recommended)**
Use NER for entities + LLM for concepts.

**Tasks:**
1. NER for people, orgs, places
2. LLM for abstract topics and concepts
3. Combine and deduplicate
4. User can merge/edit topics

### Services

```ruby
class TopicExtractionService
  # Extract topics from a transcript chunk
  def extract_from_chunk(chunk)
    # 1. NER extraction for entities
    entities = extract_entities(chunk.text)

    # 2. LLM extraction for concepts
    concepts = extract_concepts_with_llm(chunk.text)

    # 3. Create or update topics
    # 4. Create topic mentions
  end

  # Batch process entire episode
  def extract_from_episode(episode)
    episode.transcript_chunks.find_each do |chunk|
      extract_from_chunk(chunk)
    end

    # Post-processing: identify related topics
    link_related_topics(episode)
  end
end

class TopicIndexService
  # Find all episodes mentioning a topic
  def episodes_for_topic(topic)
    Episode.joins(transcript_chunks: :topic_mentions)
           .where(topic_mentions: { topic: topic })
           .distinct
  end

  # Find related topics
  def related_topics(topic, limit: 10)
    # Topics that appear in same episodes/chunks
  end

  # Topic timeline - when was it discussed?
  def topic_timeline(topic)
    # Group mentions by date
  end
end
```

### UI Components

1. **Topic Index Page**
   - List all topics sorted by frequency
   - Filter by type (person, org, event, concept)
   - Search topics

2. **Topic Detail Page**
   - Topic description
   - List of episodes mentioning topic
   - Timeline view
   - Related topics
   - Excerpt from mentions

3. **Episode Page Enhancements**
   - Show topics discussed in episode
   - Click topic to see all mentions
   - Highlight topic mentions in transcript

4. **Search Integration**
   - Filter search by topic
   - Topic facets in search results
   - "Related topics" in search results

### Pipeline Integration

Add to EpisodeProcessingJob:
```ruby
STEPS = {
  # ... existing steps ...
  extract_topics: ->(episode) { TopicExtractionService.new.extract_from_episode(episode) }
}
```

### Estimated Time: 15-20 hours

---

## Implementation Order Recommendation

1. **Docker Deployment** (6-8 hours)
   - Do this first to establish deployment infrastructure
   - Makes testing other features easier
   - Can develop in container environment

2. **Ad Detection (Transcript Analysis)** (6-10 hours)
   - Quick win using existing LLM
   - Improves search quality immediately
   - Can add audio trimming later

3. **Speaker Diarization** (8-12 hours)
   - Enhances transcript value significantly
   - Enables speaker-based search/filtering
   - Good foundation for topic extraction

4. **Topic & Entity Extraction** (15-20 hours)
   - Most complex, builds on previous features
   - Benefits from clean transcripts (ads removed)
   - Benefits from speaker info
   - Provides most value long-term

**Total Estimated Time: 35-50 hours**

---

## Notes

- All features should be toggle-able via environment variables
- Consider GPU requirements for speaker diarization
- Docker deployment should support both CPU and GPU
- Topic extraction can be run as batch job for existing episodes
- Consider incremental rollout - test each feature before moving to next