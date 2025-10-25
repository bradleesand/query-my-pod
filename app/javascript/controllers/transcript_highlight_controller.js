import { Controller } from "@hotwired/stimulus"

// Highlights and scrolls to a specific transcript chunk when navigating from search results
export default class extends Controller {
  static targets = ["skipAdsToggle", "autoScrollToggle"]

  connect() {
    // Initialize skip ads setting from localStorage
    this.skipAds = localStorage.getItem('skipAds') === 'true'

    // Update toggle UI if it exists
    if (this.hasSkipAdsToggleTarget) {
      this.skipAdsToggleTarget.checked = this.skipAds
    }

    // Initialize auto-scroll setting from localStorage (default: false)
    this.autoScroll = localStorage.getItem('autoScroll') === 'true'
    this.updateAutoScrollButton()

    // Check if there's a chunk parameter in the URL
    const params = new URLSearchParams(window.location.search)
    const chunkId = params.get('chunk')

    if (chunkId) {
      this.highlightChunk(chunkId)
    }

    // Set up live highlighting as audio plays
    this.setupAudioTracking()

    // Set up manual scroll detection
    this.setupScrollDetection()
  }

  disconnect() {
    // Clean up audio event listener
    if (this.audioPlayer) {
      this.audioPlayer.removeEventListener('timeupdate', this.handleTimeUpdate)
    }

    // Clean up scroll listener
    if (this.transcriptContainer) {
      this.transcriptContainer.removeEventListener('scroll', this.handleManualScroll)
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

  setupScrollDetection() {
    const container = this.transcriptContainer

    if (container) {
      // Bind the handler so we can remove it later
      this.handleManualScroll = this.handleManualScroll.bind(this)

      // Track if scroll was triggered programmatically
      this.isAutoScrolling = false

      container.addEventListener('scroll', this.handleManualScroll)
    }
  }

  handleManualScroll() {
    // Check if this was a programmatic scroll (from this or other controllers)
    const isProgrammatic = this.isAutoScrolling ||
                          this.transcriptContainer?.dataset.programmaticScroll === 'true'

    // Only disable auto-scroll if this was a manual scroll (not programmatic)
    if (!isProgrammatic && this.autoScroll) {
      this.autoScroll = false
      localStorage.setItem('autoScroll', 'false')
      this.updateAutoScrollButton()
      console.log('Auto-scroll disabled by manual scroll')
    }
  }

  toggleAutoScroll() {
    this.autoScroll = !this.autoScroll
    localStorage.setItem('autoScroll', this.autoScroll)
    this.updateAutoScrollButton()
    console.log('Auto-scroll:', this.autoScroll ? 'enabled' : 'disabled')
  }

  updateAutoScrollButton() {
    if (!this.hasAutoScrollToggleTarget) return

    const button = this.autoScrollToggleTarget

    if (this.autoScroll) {
      button.classList.remove('btn-outline-primary')
      button.classList.add('btn-primary')
    } else {
      button.classList.remove('btn-primary')
      button.classList.add('btn-outline-primary')
    }
  }

  get transcriptContainer() {
    return document.getElementById('transcript-container')
  }

  setupChunkClickHandlers() {
    const chunks = this.transcriptContainer?.querySelectorAll('.transcript-chunk') || []

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
    const chunks = this.transcriptContainer?.querySelectorAll('.transcript-chunk') || []
    let activeChunk = null

    for (const chunk of chunks) {
      const startTime = parseFloat(chunk.dataset.startTime)
      const endTime = parseFloat(chunk.dataset.endTime)

      if (currentTime >= startTime && currentTime < endTime) {
        activeChunk = chunk
        break
      }
    }

    // If skip ads is enabled and we're in an ad chunk, skip to the next non-ad chunk
    if (this.skipAds && activeChunk && activeChunk.classList.contains('transcript-chunk-ad')) {
      this.skipToNextNonAdChunk(activeChunk, chunks)
      return
    }

    // Remove playback highlight from all chunks (keep nav highlight if present)
    chunks.forEach(chunk => chunk.classList.remove('chunk-highlighted-playback'))

    // Highlight the active chunk with playback style
    if (activeChunk) {
      activeChunk.classList.add('chunk-highlighted-playback')

      // Only auto-scroll if enabled
      if (this.autoScroll && !this.isElementInView(activeChunk)) {
        this.scrollToChunkInContainer(activeChunk)
      }
    }
  }

  skipToNextNonAdChunk(currentChunk, chunks) {
    // Find the current chunk's index
    const chunksArray = Array.from(chunks)
    const currentIndex = chunksArray.indexOf(currentChunk)

    // Find the next non-ad chunk
    for (let i = currentIndex + 1; i < chunksArray.length; i++) {
      const chunk = chunksArray[i]
      if (!chunk.classList.contains('transcript-chunk-ad')) {
        const nextStartTime = parseFloat(chunk.dataset.startTime)
        if (!isNaN(nextStartTime)) {
          console.log('Skipping ad, jumping to', nextStartTime)
          this.audioPlayer.currentTime = nextStartTime
        }
        break
      }
    }
  }

  toggleSkipAds(event) {
    this.skipAds = event.target.checked
    localStorage.setItem('skipAds', this.skipAds)
    console.log('Skip ads:', this.skipAds ? 'enabled' : 'disabled')
  }

  scrollToChunkInContainer(chunk) {
    const container = this.transcriptContainer
    if (!container) return

    const chunkTop = chunk.offsetTop
    const chunkBottom = chunkTop + chunk.offsetHeight
    const containerScrollTop = container.scrollTop
    const containerHeight = container.clientHeight

    // Add padding so chunks aren't right at the edge
    const padding = 40 // pixels of breathing room

    // Mark as programmatic scroll to prevent disabling auto-scroll
    this.isAutoScrolling = true

    // Scroll only if chunk is outside the visible area
    if (chunkTop < containerScrollTop + padding) {
      // Chunk is above visible area - scroll up with padding
      container.scrollTop = chunkTop - padding
    } else if (chunkBottom > containerScrollTop + containerHeight - padding) {
      // Chunk is below visible area - scroll down with padding
      container.scrollTop = chunkBottom - containerHeight + padding
    }

    // Reset flag after a brief delay (scroll event fires asynchronously)
    setTimeout(() => {
      this.isAutoScrolling = false
    }, 50)
  }

  isElementInView(element) {
    const container = this.transcriptContainer
    if (!container) return true

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

      // Scroll to chunk within the transcript container (programmatic scroll)
      const container = this.transcriptContainer
      if (container) {
        this.isAutoScrolling = true
        const scrollTop = chunkElement.offsetTop - (container.clientHeight / 2) + (chunkElement.clientHeight / 2)
        container.scrollTop = scrollTop
        setTimeout(() => {
          this.isAutoScrolling = false
        }, 50)
      }

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
