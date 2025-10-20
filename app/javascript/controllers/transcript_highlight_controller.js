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

    // Set up live highlighting as audio plays
    this.setupAudioTracking()
  }

  disconnect() {
    // Clean up audio event listener
    if (this.audioPlayer) {
      this.audioPlayer.removeEventListener('timeupdate', this.handleTimeUpdate)
    }
  }

  setupAudioTracking() {
    this.audioPlayer = document.querySelector('audio')

    if (this.audioPlayer) {
      // Bind the handler so we can remove it later
      this.handleTimeUpdate = this.handleTimeUpdate.bind(this)
      this.audioPlayer.addEventListener('timeupdate', this.handleTimeUpdate)
    }

    // Add double-click listeners to chunks
    this.setupChunkClickHandlers()
  }

  setupChunkClickHandlers() {
    const chunks = this.element.querySelectorAll('.transcript-chunk')

    chunks.forEach(chunk => {
      chunk.addEventListener('click', () => {
        const startTime = parseFloat(chunk.dataset.startTime)

        if (!isNaN(startTime) && this.audioPlayer) {
          this.audioPlayer.currentTime = startTime
          // Optionally start playing
          // this.audioPlayer.play()
        }
      })

      // Add cursor style to indicate chunks are clickable
      chunk.style.cursor = 'pointer'
    })
  }

  handleTimeUpdate() {
    const currentTime = this.audioPlayer.currentTime

    // Find the chunk that matches the current playback time
    const chunks = this.element.querySelectorAll('.transcript-chunk')
    let activeChunk = null

    for (const chunk of chunks) {
      const startTime = parseFloat(chunk.dataset.startTime)
      const endTime = parseFloat(chunk.dataset.endTime)

      if (currentTime >= startTime && currentTime < endTime) {
        activeChunk = chunk
        break
      }
    }

    // Remove playback highlight from all chunks (keep nav highlight if present)
    chunks.forEach(chunk => chunk.classList.remove('chunk-highlighted-playback'))

    // Highlight the active chunk with playback style
    if (activeChunk) {
      activeChunk.classList.add('chunk-highlighted-playback')

      // Scroll within the transcript container only, not the page
      if (!this.isElementInView(activeChunk)) {
        this.scrollToChunkInContainer(activeChunk)
      }
    }
  }

  scrollToChunkInContainer(chunk) {
    const container = this.element
    const chunkTop = chunk.offsetTop
    const chunkBottom = chunkTop + chunk.offsetHeight
    const containerScrollTop = container.scrollTop
    const containerHeight = container.clientHeight

    // Add padding so chunks aren't right at the edge
    const padding = 40 // pixels of breathing room

    // Scroll only if chunk is outside the visible area
    if (chunkTop < containerScrollTop + padding) {
      // Chunk is above visible area - scroll up with padding
      container.scrollTop = chunkTop - padding
    } else if (chunkBottom > containerScrollTop + containerHeight - padding) {
      // Chunk is below visible area - scroll down with padding
      container.scrollTop = chunkBottom - containerHeight + padding
    }
  }

  isElementInView(element) {
    const container = this.element
    const elementTop = element.offsetTop
    const elementBottom = elementTop + element.offsetHeight
    const containerTop = container.scrollTop
    const containerBottom = containerTop + container.clientHeight

    return elementTop >= containerTop && elementBottom <= containerBottom
  }

  highlightChunk(chunkId) {
    const chunkElement = document.getElementById(`chunk-${chunkId}`)

    if (chunkElement) {
      // Add navigation highlight class (with dramatic animation)
      chunkElement.classList.add('chunk-highlighted-nav')

      // Scroll to chunk within the transcript container
      const container = this.element
      const scrollTop = chunkElement.offsetTop - (container.clientHeight / 2) + (chunkElement.clientHeight / 2)
      container.scrollTop = scrollTop

      // Seek audio player to chunk start time
      this.seekAudioToChunk(chunkElement)
    }
  }

  seekAudioToChunk(chunkElement) {
    const startTime = parseFloat(chunkElement.dataset.startTime)

    if (!isNaN(startTime)) {
      const audioPlayer = document.querySelector('audio')

      if (audioPlayer) {
        const setTime = () => {
          audioPlayer.currentTime = startTime
        }

        // Wait for audio to be ready before seeking
        if (audioPlayer.readyState >= 3) {
          setTime()
        } else {
          audioPlayer.addEventListener('canplay', setTime, { once: true })
        }
      }
    }
  }
}
