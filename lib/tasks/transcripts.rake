namespace :transcripts do
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
        chunk.update!(embedding: embedding.to_json)
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