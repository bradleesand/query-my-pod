import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chunk", "editToggle", "actionButtons", "startChunk", "endChunk"]
  static values = {
    episodeId: Number
  }

  connect() {
    console.log("ChunkEditor controller connected")
    this.editMode = false
    this.startChunkId = null
    this.endChunkId = null
    this.currentAdIndex = -1
  }

  toggleEditMode() {
    this.editMode = !this.editMode

    if (this.editMode) {
      // Entering edit mode
      this.element.classList.add("edit-mode")
      this.editToggleTarget.textContent = "Exit Edit Mode"
      this.editToggleTarget.classList.remove("btn-outline-secondary")
      this.editToggleTarget.classList.add("btn-warning")
      this.actionButtonsTarget.classList.remove("d-none")
    } else {
      // Exiting edit mode
      this.element.classList.remove("edit-mode")
      this.editToggleTarget.textContent = "Edit Mode"
      this.editToggleTarget.classList.remove("btn-warning")
      this.editToggleTarget.classList.add("btn-outline-secondary")
      this.actionButtonsTarget.classList.add("d-none")
      this.clearSelection()
    }
  }

  selectChunk(event) {
    if (!this.editMode) return

    const chunk = event.currentTarget
    const chunkId = parseInt(chunk.dataset.chunkId)

    // First click - set start
    if (!this.startChunkId) {
      this.startChunkId = chunkId
      this.updateSelection()
    }
    // Second click - set end
    else if (!this.endChunkId && chunkId !== this.startChunkId) {
      this.endChunkId = chunkId
      this.updateSelection()
    }
    // Third click - reset and start over
    else {
      this.clearSelection()
      this.startChunkId = chunkId
      this.updateSelection()
    }
  }

  updateSelection() {
    // Clear previous selection styling
    this.chunkTargets.forEach(chunk => {
      chunk.classList.remove("chunk-selected", "chunk-range-start", "chunk-range-end")
    })

    if (!this.startChunkId) return

    // Find start and end indices
    const startIdx = this.chunkTargets.findIndex(c => parseInt(c.dataset.chunkId) === this.startChunkId)
    const endIdx = this.endChunkId ?
      this.chunkTargets.findIndex(c => parseInt(c.dataset.chunkId) === this.endChunkId) :
      startIdx

    // Ensure start is before end
    const [fromIdx, toIdx] = startIdx <= endIdx ? [startIdx, endIdx] : [endIdx, startIdx]

    // Highlight the range
    for (let i = fromIdx; i <= toIdx; i++) {
      this.chunkTargets[i].classList.add("chunk-selected")
      if (i === fromIdx) this.chunkTargets[i].classList.add("chunk-range-start")
      if (i === toIdx) this.chunkTargets[i].classList.add("chunk-range-end")
    }

    // Update display
    this.updateSelectionDisplay()
  }

  updateSelectionDisplay() {
    const count = this.getSelectedChunkIds().length
    if (count > 0) {
      this.startChunkTarget.textContent = `${count} chunk${count > 1 ? 's' : ''} selected`
    } else {
      this.startChunkTarget.textContent = "Click to select start"
    }

    if (this.startChunkId && !this.endChunkId) {
      this.endChunkTarget.textContent = "Click to select end"
    } else if (this.endChunkId) {
      this.endChunkTarget.textContent = ""
    } else {
      this.endChunkTarget.textContent = ""
    }
  }

  clearSelection() {
    this.startChunkId = null
    this.endChunkId = null
    this.chunkTargets.forEach(chunk => {
      chunk.classList.remove("chunk-selected", "chunk-range-start", "chunk-range-end")
    })
    this.updateSelectionDisplay()
  }

  getSelectedChunkIds() {
    if (!this.startChunkId) return []

    const startIdx = this.chunkTargets.findIndex(c => parseInt(c.dataset.chunkId) === this.startChunkId)
    const endIdx = this.endChunkId ?
      this.chunkTargets.findIndex(c => parseInt(c.dataset.chunkId) === this.endChunkId) :
      startIdx

    const [fromIdx, toIdx] = startIdx <= endIdx ? [startIdx, endIdx] : [endIdx, startIdx]

    const chunkIds = []
    for (let i = fromIdx; i <= toIdx; i++) {
      chunkIds.push(parseInt(this.chunkTargets[i].dataset.chunkId))
    }

    return chunkIds
  }

  async markAsAd() {
    const chunkIds = this.getSelectedChunkIds()
    if (chunkIds.length === 0) {
      alert("Please select chunks first")
      return
    }

    if (!confirm(`Mark ${chunkIds.length} chunk(s) as advertisement?`)) return

    await this.updateChunks(chunkIds, "advertisement")
  }

  async markAsContent() {
    const chunkIds = this.getSelectedChunkIds()
    if (chunkIds.length === 0) {
      alert("Please select chunks first")
      return
    }

    if (!confirm(`Mark ${chunkIds.length} chunk(s) as content (not ad)?`)) return

    await this.updateChunks(chunkIds, "transcript")
  }

  getAdClusters() {
    // Group consecutive ad chunks into clusters
    const clusters = []
    let currentCluster = []

    this.chunkTargets.forEach((chunk, index) => {
      if (chunk.classList.contains('transcript-chunk-ad')) {
        currentCluster.push({ chunk, index })
      } else {
        // Non-ad chunk - end current cluster if it exists
        if (currentCluster.length > 0) {
          clusters.push(currentCluster)
          currentCluster = []
        }
      }
    })

    // Don't forget the last cluster if transcript ends with ads
    if (currentCluster.length > 0) {
      clusters.push(currentCluster)
    }

    return clusters
  }

  jumpToNextAd() {
    if (!this.editMode) return

    const clusters = this.getAdClusters()

    if (clusters.length === 0) {
      alert("No advertisement chunks found")
      return
    }

    // Move to next cluster (with wraparound)
    this.currentAdIndex = (this.currentAdIndex + 1) % clusters.length
    const cluster = clusters[this.currentAdIndex]

    // Select the entire cluster
    this.selectCluster(cluster)
  }

  jumpToPreviousAd() {
    if (!this.editMode) return

    const clusters = this.getAdClusters()

    if (clusters.length === 0) {
      alert("No advertisement chunks found")
      return
    }

    // Move to previous cluster (with wraparound)
    this.currentAdIndex = (this.currentAdIndex - 1 + clusters.length) % clusters.length
    const cluster = clusters[this.currentAdIndex]

    // Select the entire cluster
    this.selectCluster(cluster)
  }

  selectCluster(cluster) {
    // Clear current selection
    this.clearSelection()

    // Select the cluster range (first to last chunk in cluster)
    const firstChunk = cluster[0].chunk
    const lastChunk = cluster[cluster.length - 1].chunk

    this.startChunkId = parseInt(firstChunk.dataset.chunkId)
    this.endChunkId = parseInt(lastChunk.dataset.chunkId)
    this.updateSelection()

    // Scroll to the cluster (center the first chunk)
    const container = document.getElementById('transcript-container')
    if (container) {
      const chunkTop = firstChunk.offsetTop
      const containerHeight = container.clientHeight
      container.scrollTop = chunkTop - (containerHeight / 2) + (firstChunk.offsetHeight / 2)
    }
  }

  async updateChunks(chunkIds, chunkType) {
    try {
      const response = await fetch(`/episodes/${this.episodeIdValue}/bulk_update_chunks`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          chunk_ids: chunkIds,
          chunk_type: chunkType
        })
      })

      if (response.ok) {
        // Reload the page to show updated chunks
        window.location.reload()
      } else {
        alert("Failed to update chunks")
      }
    } catch (error) {
      console.error("Error updating chunks:", error)
      alert("Error updating chunks")
    }
  }
}