import { Controller } from "@hotwired/stimulus"

// Onboarding overlay controller
// Handles keyboard navigation and menu item highlighting
export default class extends Controller {
  static targets = ["backdrop", "content", "continueButton"]
  static values = {
    step: String,
    highlight: String
  }

  connect() {
    this.bindKeyboardEvents()
    this.highlightMenuItem()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyDown)
    this.removeHighlight()
  }

  bindKeyboardEvents() {
    this.handleKeyDown = this.onKeyDown.bind(this)
    document.addEventListener("keydown", this.handleKeyDown)
  }

  onKeyDown(event) {
    switch(event.key) {
      case 'Enter':
        event.preventDefault()
        this.advance()
        break
      case 'Escape':
        event.preventDefault()
        this.skip()
        break
    }
  }

  advance() {
    if (this.hasContinueButtonTarget) {
      this.continueButtonTarget.click()
    }
  }

  skip() {
    // Trigger skip by navigating to skip path
    const form = this.element.querySelector('form[action*="skip"]')
    if (form) {
      form.requestSubmit()
    }
  }

  focusOverlay() {
    // Clicking backdrop refocuses the overlay (doesn't dismiss it)
    if (this.hasContentTarget) {
      this.contentTarget.focus()
    }
  }

  highlightMenuItem() {
    if (!this.highlightValue) return

    // Find the menu item to highlight
    const menuItem = document.querySelector(this.highlightValue)
    if (menuItem) {
      // Add highlight classes - uses CSS animation defined in application.css
      menuItem.classList.add(
        "ring-2",
        "ring-orange-500",
        "ring-offset-2",
        "ring-offset-blue-950",
        "bg-orange-500/20",
        "rounded",
        "onboarding-highlight"
      )

      // Store reference for cleanup
      this.highlightedElement = menuItem

      // Scroll into view if needed, with offset for sidebar
      menuItem.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  }

  removeHighlight() {
    const highlightClasses = [
      "ring-2",
      "ring-orange-500",
      "ring-offset-2",
      "ring-offset-blue-950",
      "bg-orange-500/20",
      "rounded",
      "onboarding-highlight"
    ]

    if (this.highlightedElement) {
      this.highlightedElement.classList.remove(...highlightClasses)
    }

    // Also remove any leftover highlights
    document.querySelectorAll('.onboarding-highlight').forEach(el => {
      el.classList.remove(...highlightClasses)
    })
  }

  stepValueChanged() {
    // When step changes, update the highlight
    this.removeHighlight()
    this.highlightMenuItem()
  }
}
