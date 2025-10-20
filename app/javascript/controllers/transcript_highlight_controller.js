import { Controller } from "@hotwired/stimulus"

// Highlights and scrolls to a specific transcript chunk when navigating from search results
export default class extends Controller {
  connect() {
    // Check if there's a chunk parameter in the URL
    const params = new URLSearchParams(window.location.search)
    const chunkId = params.get('chunk')

    if (chunkId) {
      this.highlightChunk(chunkId)
    }
  }

  highlightChunk(chunkId) {
    const chunkElement = document.getElementById(`chunk-${chunkId}`)

    if (chunkElement) {
      // Add highlight class
      chunkElement.classList.add('chunk-highlighted')

      // Scroll to chunk within the transcript container
      const container = this.element
      const containerRect = container.getBoundingClientRect()
      const chunkRect = chunkElement.getBoundingClientRect()

      // Calculate scroll position to center the chunk in the container
      const scrollTop = chunkElement.offsetTop - (container.clientHeight / 2) + (chunkElement.clientHeight / 2)
      container.scrollTop = scrollTop
    }
  }
}
