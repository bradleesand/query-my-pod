#!/usr/bin/env ruby
# Test script to check if Qwen 2.5 supports tool/function calling in Ollama

require 'net/http'
require 'json'
require 'uri'

OLLAMA_URL = ENV.fetch("OLLAMA_API_URL", "http://localhost:11434")
MODEL = ENV.fetch("OLLAMA_MODEL", "qwen2.5:7b")

puts "Testing Ollama tool calling support"
puts "URL: #{OLLAMA_URL}"
puts "Model: #{MODEL}"
puts "-" * 80

# Define a simple tool
tools = [
  {
    type: "function",
    function: {
      name: "search_transcript",
      description: "Search for additional information in the podcast transcript",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "The search query to find more context"
          },
          num_results: {
            type: "integer",
            description: "Number of additional results to retrieve",
            default: 5
          }
        },
        required: ["query"]
      }
    }
  }
]

# Test message
messages = [
  {
    role: "system",
    content: "You are a helpful assistant that answers questions about podcasts. You have access to tools to search for more information."
  },
  {
    role: "user",
    content: "Can you tell me about productivity tips? If you need more context, please search for it."
  }
]

# Prepare request
uri = URI.parse("#{OLLAMA_URL}/api/chat")
request = Net::HTTP::Post.new(uri)
request.content_type = "application/json"
request.body = JSON.generate({
  model: MODEL,
  messages: messages,
  tools: tools,
  stream: false
})

puts "\nSending request with tools defined..."
puts "Request body:"
puts JSON.pretty_generate(JSON.parse(request.body))
puts "\n" + "-" * 80

begin
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.read_timeout = 120
    http.request(request)
  end

  if response.code == "200"
    result = JSON.parse(response.body)
    puts "\n✅ SUCCESS - Ollama accepted the request"
    puts "\nResponse:"
    puts JSON.pretty_generate(result)

    # Check if the model used tools
    if result.dig("message", "tool_calls")
      puts "\n" + "=" * 80
      puts "🎉 TOOL CALLING IS SUPPORTED!"
      puts "=" * 80
      puts "\nTool calls made by the model:"
      puts JSON.pretty_generate(result["message"]["tool_calls"])
    elsif result.dig("message", "content")
      puts "\n" + "=" * 80
      puts "⚠️  Model responded but did NOT use tools"
      puts "=" * 80
      puts "\nModel's response:"
      puts result["message"]["content"]
      puts "\nThis could mean:"
      puts "1. The model doesn't support tool calling"
      puts "2. The model didn't think it needed to call the tool"
      puts "3. Try with a more explicit prompt that requires the tool"
    end
  else
    puts "\n❌ ERROR - HTTP #{response.code}"
    puts response.body
  end

rescue Errno::ECONNREFUSED
  puts "\n❌ ERROR - Cannot connect to Ollama at #{OLLAMA_URL}"
  puts "Make sure Ollama is running with: ollama serve"
rescue => e
  puts "\n❌ ERROR - #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 80
puts "DOCUMENTATION"
puts "=" * 80
puts "Ollama tool calling docs: https://github.com/ollama/ollama/blob/main/docs/api.md#tools"
puts "Qwen 2.5 info: https://ollama.com/library/qwen2.5"
puts "\nModels known to support tools in Ollama:"
puts "  - llama3.1, llama3.2, llama3.3"
puts "  - mistral, mixtral"
puts "  - qwen2.5 (should support, but verification needed)"
puts "  - firefunction-v2"