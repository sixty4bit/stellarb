import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="route-stops-edit"
// Provides keyboard navigation and auto-save for route stops editing
export default class extends Controller {
  static targets = ["stop", "intent"]
  static values = {
    routeId: Number,
    saveDelay: { type: Number, default: 500 }
  }

  connect() {
    this.selectedStopIndex = 0
    this.selectedIntentIndex = -1
    this.updateSelection()
  }

  // Keyboard navigation
  keydown(event) {
    switch (event.key) {
      case "j":
      case "ArrowDown":
        event.preventDefault()
        this.moveDown()
        break
      case "k":
      case "ArrowUp":
        event.preventDefault()
        this.moveUp()
        break
      case "Enter":
        event.preventDefault()
        this.editSelected()
        break
      case "x":
      case "Delete":
        event.preventDefault()
        this.deleteSelected()
        break
      case "a":
        event.preventDefault()
        this.addIntent()
        break
      case "Escape":
        this.clearSelection()
        break
    }
  }

  moveDown() {
    if (this.selectedIntentIndex >= 0) {
      // Moving within intents
      const stop = this.stopTargets[this.selectedStopIndex]
      const intents = stop?.querySelectorAll("[data-route-stops-edit-target='intent']")
      if (intents && this.selectedIntentIndex < intents.length - 1) {
        this.selectedIntentIndex++
      } else {
        // Move to next stop
        this.selectedIntentIndex = -1
        if (this.selectedStopIndex < this.stopTargets.length - 1) {
          this.selectedStopIndex++
        }
      }
    } else {
      // Moving between stops
      if (this.selectedStopIndex < this.stopTargets.length - 1) {
        this.selectedStopIndex++
      }
    }
    this.updateSelection()
  }

  moveUp() {
    if (this.selectedIntentIndex > 0) {
      this.selectedIntentIndex--
    } else if (this.selectedIntentIndex === 0) {
      this.selectedIntentIndex = -1
    } else if (this.selectedStopIndex > 0) {
      this.selectedStopIndex--
    }
    this.updateSelection()
  }

  updateSelection() {
    // Clear all selections
    this.stopTargets.forEach(stop => {
      stop.classList.remove("ring-2", "ring-orange-400")
      const intents = stop.querySelectorAll("[data-route-stops-edit-target='intent']")
      intents.forEach(intent => intent.classList.remove("ring-2", "ring-lime-400"))
    })

    // Apply selection
    const selectedStop = this.stopTargets[this.selectedStopIndex]
    if (selectedStop) {
      if (this.selectedIntentIndex >= 0) {
        const intents = selectedStop.querySelectorAll("[data-route-stops-edit-target='intent']")
        const selectedIntent = intents[this.selectedIntentIndex]
        if (selectedIntent) {
          selectedIntent.classList.add("ring-2", "ring-lime-400")
          selectedIntent.scrollIntoView({ block: "nearest" })
        }
      } else {
        selectedStop.classList.add("ring-2", "ring-orange-400")
        selectedStop.scrollIntoView({ block: "nearest" })
      }
    }
  }

  clearSelection() {
    this.selectedStopIndex = 0
    this.selectedIntentIndex = -1
    this.updateSelection()
  }

  editSelected() {
    const selectedStop = this.stopTargets[this.selectedStopIndex]
    if (!selectedStop) return

    if (this.selectedIntentIndex >= 0) {
      // Enter intent intents list
      this.selectedIntentIndex = 0
    } else {
      // Enter stop's intent list
      const intents = selectedStop.querySelectorAll("[data-route-stops-edit-target='intent']")
      if (intents.length > 0) {
        this.selectedIntentIndex = 0
      }
    }
    this.updateSelection()
  }

  deleteSelected() {
    const selectedStop = this.stopTargets[this.selectedStopIndex]
    if (!selectedStop) return

    if (this.selectedIntentIndex >= 0) {
      // Delete intent
      const deleteBtn = selectedStop.querySelectorAll("[data-route-stops-edit-target='intent'] button[data-turbo-method='delete']")[this.selectedIntentIndex]
      if (deleteBtn) deleteBtn.click()
    } else {
      // Delete stop
      const deleteBtn = selectedStop.querySelector("button[data-turbo-method='delete']")
      if (deleteBtn) deleteBtn.click()
    }
  }

  addIntent() {
    const selectedStop = this.stopTargets[this.selectedStopIndex]
    if (!selectedStop) return

    // Focus the type select in the add intent form
    const typeSelect = selectedStop.querySelector("select[name='intent[type]']")
    if (typeSelect) typeSelect.focus()
  }

  // Auto-save on input change (debounced)
  autoSave(event) {
    const form = event.target.closest("form")
    if (!form) return

    clearTimeout(this.saveTimeout)
    this.saveTimeout = setTimeout(() => {
      // Don't auto-submit for now - requires more infrastructure
      // form.requestSubmit()
    }, this.saveDelayValue)
  }

  // Called when stops list is updated via Turbo Stream
  stopTargetConnected(element) {
    this.updateSelection()
  }

  stopTargetDisconnected(element) {
    // Reset selection if the selected stop was removed
    if (this.selectedStopIndex >= this.stopTargets.length) {
      this.selectedStopIndex = Math.max(0, this.stopTargets.length - 1)
    }
    this.updateSelection()
  }
}
