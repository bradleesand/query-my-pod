#!/usr/bin/env ruby
# CLI tool to query the LLM with semantic search
# Usage: rails runner scripts/query_llm.rb "your question here" [options]

require 'optparse'

# Parse command line options
options = {
  context: 'all',
  limit: AppConfig.search_context_chunks,
  listened_filter: 'all',
  podcast_id: nil,
  episode_id: nil,
  verbose: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: rails runner scripts/query_llm.rb \"your question\" [options]"

  opts.on("-c", "--context CONTEXT", "Search context: all, podcast, episode") do |c|
    options[:context] = c
  end

  opts.on("-p", "--podcast ID", Integer, "Podcast ID (for podcast/episode context)") do |p|
    options[:podcast_id] = p
  end

  opts.on("-e", "--episode ID", Integer, "Episode ID (for episode context)") do |e|
    options[:episode_id] = e
  end

  opts.on("-l", "--limit N", Integer, "Number of initial context chunks (default: #{options[:limit]})") do |l|
    options[:limit] = l
  end

  opts.on("-f", "--filter FILTER", "Listened filter: all, listened, unlistened") do |f|
    options[:listened_filter] = f
  end

  opts.on("-v", "--verbose", "Show detailed information including sources") do
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Get query from arguments
query = ARGV.join(" ")

if query.blank?
  puts "Error: Please provide a query"
  puts "Usage: rails runner scripts/query_llm.rb \"your question\" [options]"
  puts "Use -h for help"
  exit 1
end

# Determine search scope
podcast_id = nil
episode_id = nil

case options[:context]
when "episode"
  if options[:episode_id].nil?
    puts "Error: --episode ID required for episode context"
    exit 1
  end
  episode_id = options[:episode_id]
when "podcast"
  if options[:podcast_id].nil?
    puts "Error: --podcast ID required for podcast context"
    exit 1
  end
  podcast_id = options[:podcast_id]
when "all"
  # Search all podcasts
else
  puts "Error: Invalid context '#{options[:context]}'. Use: all, podcast, or episode"
  exit 1
end

puts "=" * 80
puts "PODCAST SEARCH - LLM QUERY"
puts "=" * 80
puts "Query: #{query}"
puts "Context: #{options[:context]}"
puts "Podcast ID: #{podcast_id || 'all'}"
puts "Episode ID: #{episode_id || 'all'}"
puts "Limit: #{options[:limit]} chunks"
puts "Listened Filter: #{options[:listened_filter]}"
puts "=" * 80
puts

# Perform vector search
puts "🔍 Searching transcripts..."
search_service = TranscriptSearchService.new(query,
  podcast_id: podcast_id,
  episode_id: episode_id,
  limit: options[:limit],
  listened_filter: options[:listened_filter])
search_results = search_service.search

if search_results.empty?
  puts "❌ No results found for your query"
  exit 0
end

puts "✅ Found #{search_results.length} relevant excerpt(s)"
puts

# Generate LLM response
puts "🤖 Generating LLM response..."
context_options = {
  podcast_id: podcast_id,
  episode_id: episode_id,
  listened_filter: options[:listened_filter]
}
llm_service = LlmQueryService.new(query, search_results, context_options)
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
    puts
    puts "[#{source[:index]}] #{source[:episode_title]}"
    puts "    Podcast: #{source[:podcast_title]}"
    puts "    Time: #{source[:timestamp]}"
    puts "    Similarity: #{((1 - source[:distance]) * 100).round(1)}%" if source[:distance]
    puts "    ---"
    puts "    #{source[:text]}"
  end
  puts
end

puts "=" * 80
puts "✅ Query complete!"
puts "=" * 80
