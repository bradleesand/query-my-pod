namespace :transcripts do
  desc "Create title and description chunks for all episodes"
  task create_metadata_chunks: :environment do
    episodes = Episode.all
    total = episodes.count

    puts "Found #{total} episodes"
    puts "Creating title and description chunks for episodes that don't have them..."

    created = 0
    skipped = 0

    episodes.find_each.with_index do |episode, index|
      print "\rProcessing episode #{index + 1}/#{total} (ID: #{episode.id})..."

      # Check if title and description chunks already exist
      has_title = episode.transcript_chunks.title.exists?
      has_description = episode.transcript_chunks.description.exists?

      chunks_added = 0

      # Create title chunk if missing
      if !has_title && episode.title.present?
        TranscriptChunk.create!(
          episode: episode,
          text: episode.title,
          start_time: nil,
          end_time: nil,
          chunk_index: -2,
          chunk_type: "title"
        )
        chunks_added += 1
      end

      # Create description chunk if missing
      if !has_description && episode.description.present?
        TranscriptChunk.create!(
          episode: episode,
          text: episode.description,
          start_time: nil,
          end_time: nil,
          chunk_index: -1,
          chunk_type: "description"
        )
        chunks_added += 1
      end

      if chunks_added > 0
        created += chunks_added
        puts " ✓ Created #{chunks_added} chunk(s)"
      else
        skipped += 1
      end
    end

    puts "\n\nDone!"
    puts "✓ Created #{created} metadata chunks"
    puts "⊘ Skipped #{skipped} episodes (already had metadata chunks or missing title/description)"

    # Show summary
    title_chunks = TranscriptChunk.title.count
    description_chunks = TranscriptChunk.description.count
    puts "\nTotal metadata chunks in database:"
    puts "  Title chunks: #{title_chunks}"
    puts "  Description chunks: #{description_chunks}"
  end

  desc "Chunk all completed transcripts into searchable segments"
  task chunk: :environment do
    episodes = Episode.where(transcription_status: :completed)
    total = episodes.count

    puts "Found #{total} episodes with completed transcripts"

    episodes.find_each.with_index do |episode, index|
      print "\rProcessing episode #{index + 1}/#{total} (ID: #{episode.id})..."

      result = TranscriptChunkingService.new(episode).chunk

      if result
        chunk_count = episode.transcript_chunks.count
        puts " ✓ Created #{chunk_count} chunks"
      else
        puts " ✗ Failed"
      end
    end

    total_chunks = TranscriptChunk.count
    puts "\nDone! Total chunks in database: #{total_chunks}"
  end

  desc "Generate embeddings for all chunks without embeddings"
  task generate_embeddings: :environment do
    chunks = TranscriptChunk.where(embedding: nil)
    total = chunks.count

    if total.zero?
      puts "All chunks already have embeddings!"
      next
    end

    puts "Found #{total} chunks without embeddings"
    puts "Generating embeddings using sentence-transformers/all-MiniLM-L6-v2..."

    embedding_service = EmbeddingService.new
    processed = 0
    failed = 0

    chunks.find_each do |chunk|
      processed += 1
      print "\rProcessing chunk #{processed}/#{total} (Episode #{chunk.episode_id})..."

      embedding = embedding_service.generate(chunk.text)

      if embedding
        chunk.update!(embedding: embedding)
      else
        failed += 1
        puts "\n✗ Failed to generate embedding for chunk #{chunk.id}"
      end
    end

    puts "\n\nDone!"
    puts "✓ Successfully generated embeddings: #{processed - failed}"
    puts "✗ Failed: #{failed}" if failed > 0
  end
end
