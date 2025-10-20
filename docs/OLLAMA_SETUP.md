# Ollama Setup Guide

This guide explains how to set up Ollama for the RAG (Retrieval Augmented Generation) feature.

## What is Ollama?

Ollama is a tool for running large language models (LLMs) locally on your machine. It provides an easy-to-use API for interacting with models like Llama, Mistral, and Phi.

## Installation

### macOS

Download and install from the official website:
```bash
# Visit https://ollama.ai and download the macOS app
# Or use Homebrew:
brew install ollama
```

### Linux

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

## Starting Ollama

Ollama runs as a background service. To start it:

```bash
ollama serve
```

Or if you installed the macOS app, it will start automatically.

## Pulling a Model

Before you can use the LLM integration, you need to download a model. We recommend starting with `llama3.2`:

```bash
# Pull the llama3.2 model (smaller, faster)
ollama pull llama3.2

# Or pull a larger model for better quality
ollama pull llama3.1

# Or pull mistral (good balance of speed and quality)
ollama pull mistral
```

## Verifying Installation

Check that Ollama is running and the model is available:

```bash
# List installed models
ollama list

# Test the model
ollama run llama3.2 "Hello, how are you?"
```

## Configuration

Update your `.env` file with Ollama settings:

```bash
# Ollama API endpoint (default: http://localhost:11434)
OLLAMA_API_URL=http://localhost:11434

# Model name (must match a pulled model)
OLLAMA_MODEL=llama3.2

# Number of search results to use as context
SEARCH_CONTEXT_CHUNKS=5
```

## Testing the Integration

Once Ollama is running with a model installed, test the integration:

```bash
rails runner /tmp/test_llm.rb
```

You should see:
1. Search results from the vector database
2. An LLM-generated response with citations
3. Source information showing which transcript chunks were used

## Model Recommendations

- **llama3.2** (3B params): Fast, good for development, requires ~2GB RAM
- **llama3.1** (8B params): Better quality, requires ~4-8GB RAM
- **mistral** (7B params): Good balance of speed and quality
- **phi** (2.7B params): Very fast, smaller model

## Troubleshooting

### "Ollama API error: 404 Not Found"
- Ollama is not running. Start it with `ollama serve`

### "Model not found"
- The model specified in OLLAMA_MODEL is not installed
- Run `ollama pull <model-name>` to download it

### Slow responses
- The model is too large for your hardware
- Try a smaller model like `llama3.2` or `phi`

### Connection refused
- Check that OLLAMA_API_URL matches where Ollama is running
- Default is `http://localhost:11434`

## API Reference

The Ollama API endpoint used by this application:

```
POST http://localhost:11434/api/generate
Content-Type: application/json

{
  "model": "llama3.2",
  "prompt": "Your prompt here",
  "stream": false
}
```

For more information, see: https://github.com/ollama/ollama/blob/main/docs/api.md
