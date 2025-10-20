#!/usr/bin/env python3
"""
Generate text embeddings using sentence-transformers.
Reads text from stdin and outputs embedding as JSON array.
"""

import sys
import json
from sentence_transformers import SentenceTransformer

# Load the model (cached after first run)
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
model = SentenceTransformer(MODEL_NAME)

def generate_embedding(text):
    """Generate embedding for given text."""
    # Generate embedding (returns numpy array)
    embedding = model.encode(text)

    # Convert to list for JSON serialization
    return embedding.tolist()

if __name__ == "__main__":
    # Read text from stdin
    text = sys.stdin.read().strip()

    if not text:
        print("Error: No text provided", file=sys.stderr)
        sys.exit(1)

    # Generate and output embedding
    embedding = generate_embedding(text)

    # Output as JSON
    print(json.dumps(embedding))