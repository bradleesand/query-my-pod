#!/usr/bin/env ruby
# CLI tool to query the LLM with semantic search
# Usage: rails runner scripts/query_llm.rb "your question here" [options]

require 'optparse'

# Parse command line options
options = {
  podcast_id: nil,
  episode_id: nil,
  verbose: false,
  debug: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: rails runner scripts/query_llm.rb \"your question\" [options]"

  opts.on("-p", "--podcast ID", Integer, "Podcast ID (optional context hint for LLM)") do |p|
    options[:podcast_id] = p
  end

  opts.on("-e", "--episode ID", Integer, "Episode ID (optional context hint for LLM)") do |e|
    options[:episode_id] = e
  end

  opts.on("-v", "--verbose", "Show detailed information including sources") do
    options[:verbose] = true
  end

  opts.on("-d", "--debug", "Enable debug logging (shows LLM conversation)") do
    options[:debug] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Enable debug logging if requested
if options[:debug]
  # Redirect Rails logger to stdout for debugging
  Rails.logger = Logger.new(STDOUT)
  Rails.logger.level = Logger::DEBUG
  puts "Debug logging enabled"
  puts
end

# Get query from arguments
query = ARGV.join(" ")

if query.blank?
  puts "Error: Please provide a query"
  puts "Usage: rails runner scripts/query_llm.rb \"your question\" [options]"
  puts "Use -h for help"
  exit 1
end

# Build page context for LLM
page_context = {}
if options[:episode_id]
  episode = Episode.find_by(id: options[:episode_id])
  if episode
    page_context[:episode_id] = episode.id
    page_context[:episode_title] = episode.title
    page_context[:podcast_id] = episode.podcast_id
    page_context[:podcast_title] = episode.podcast.title
  else
    puts "Error: Episode #{options[:episode_id]} not found"
    exit 1
  end
elsif options[:podcast_id]
  podcast = Podcast.find_by(id: options[:podcast_id])
  if podcast
    page_context[:podcast_id] = podcast.id
    page_context[:podcast_title] = podcast.title
  else
    puts "Error: Podcast #{options[:podcast_id]} not found"
    exit 1
  end
end

puts "=" * 80
puts "Query My Pod - LLM QUERY"
puts "=" * 80
puts "Query: #{query}"
if page_context[:episode_id]
  puts "Context: Episode \"#{page_context[:episode_title]}\" (#{page_context[:podcast_title]})"
elsif page_context[:podcast_id]
  puts "Context: Podcast \"#{page_context[:podcast_title]}\""
else
  puts "Context: All podcasts"
end
puts "=" * 80
puts

# Generate LLM response (LLM will gather all information via tools)
puts "🤖 Querying LLM (will use tools to search transcripts)..."
llm_service = LlmQueryService.new(query, page_context)
llm_response = llm_service.generate_response

if llm_response[:error]
  puts "❌ Error: #{llm_response[:error]}"
  exit 1
end

# Display results
puts "=" * 80
puts "ANSWER"
puts "=" * 80
puts llm_response[:response]
puts

if llm_response[:tool_calls_made] && llm_response[:tool_calls_made] > 0
  puts "🔧 Tool calls made: #{llm_response[:tool_calls_made]}"
  puts
end

if options[:verbose]
  puts "=" * 80
  puts "SOURCES (#{llm_response[:sources].length} total)"
  puts "=" * 80
  llm_response[:sources].each do |source|
    # Format chunk type label
    chunk_type_label = case source[:chunk_type]
    when "title" then "[EPISODE TITLE]"
    when "description" then "[EPISODE DESCRIPTION]"
    when "advertisement" then "[ADVERTISEMENT]"
    else "[TRANSCRIPT]"
    end

    puts
    puts "[Chunk #{source[:chunk]&.id}] #{chunk_type_label} #{source[:episode]&.title}"
    puts "    Podcast: #{source[:podcast]&.title}"
    if source[:chunk_type].in?(["transcript", "advertisement"])
      puts "    Time: #{source[:timestamp]}"
    else
      puts "    Metadata chunk (no timestamp)"
    end
    puts "    Similarity: #{((1 - source[:distance]) * 100).round(1)}%" if source[:distance]
    puts "    ---"
    puts "    #{source[:text]}"
  end
  puts
end

puts "=" * 80
puts "✅ Query complete!"
puts "=" * 80
