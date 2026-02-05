import { Controller } from "@hotwired/stimulus"

// Animates the unread counter badge when count changes
// Highlights on increment, then fades back to normal
export default class extends Controller {
  static values = { count: Number }

  connect() {
    this.previousCount = this.countValue || 0
  }

  countValueChanged() {
    const newCount = this.countValue

    if (newCount > this.previousCount) {
      this.pulse()
    }

    this.previousCount = newCount
  }

  pulse() {
    // Add highlight animation
    this.element.classList.add("animate-pulse-once")

    // Scale up and glow
    this.element.classList.add("scale-125", "ring-2", "ring-orange-300")

    // Remove after animation completes
    setTimeout(() => {
      this.element.classList.remove("scale-125", "ring-2", "ring-orange-300")
    }, 300)

    setTimeout(() => {
      this.element.classList.remove("animate-pulse-once")
    }, 600)
  }
}
