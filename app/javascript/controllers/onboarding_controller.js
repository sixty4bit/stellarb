import { Controller } from "@hotwired/stimulus"

// Onboarding sidebar controller
// Handles keyboard navigation, menu item highlighting, and sidebar interactions
// Works with non-blocking sidebar layout that lets users see the actual UI
export default class extends Controller {
  static targets = ["content", "continueButton"]
  static values = {
    step: String,
    highlight: String,
    mobileOnly: Boolean
  }

  connect() {
    // Auto-advance mobile-only steps on desktop (sm+ breakpoint = 640px)
    if (this.mobileOnlyValue && window.matchMedia("(min-width: 640px)").matches) {
      this.advance()
      return
    }

    this.bindKeyboardEvents()
    this.highlightMenuItem()
    
    // Small delay to ensure DOM is ready, then scroll highlighted item into view
    setTimeout(() => this.ensureHighlightVisible(), 100)
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
    // Only handle if not typing in an input
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
      return
    }

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
    }
  }

  ensureHighlightVisible() {
    if (this.highlightedElement) {
      // Scroll into view with some breathing room
      this.highlightedElement.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'center',
        inline: 'nearest'
      })
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
      this.highlightedElement = null
    }

    // Also remove any leftover highlights (defensive cleanup)
    document.querySelectorAll('.onboarding-highlight').forEach(el => {
      el.classList.remove(...highlightClasses)
    })
  }

  stepValueChanged() {
    // When step changes, update the highlight
    this.removeHighlight()
    this.highlightMenuItem()
    this.ensureHighlightVisible()
  }
}
