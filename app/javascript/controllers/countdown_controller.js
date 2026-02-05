import { Controller } from "@hotwired/stimulus"

/**
 * Countdown Controller
 * 
 * Displays a live countdown to a target timestamp.
 * When the countdown reaches zero, optionally refreshes the page.
 * 
 * Usage:
 *   <span data-controller="countdown" 
 *         data-countdown-arrival-value="2026-02-05T20:30:00Z"
 *         data-countdown-refresh-value="true">
 *     Loading...
 *   </span>
 */
export default class extends Controller {
  static values = {
    arrival: String,     // ISO 8601 timestamp of arrival
    refresh: { type: Boolean, default: true }  // Whether to refresh page on arrival
  }

  connect() {
    this.updateCountdown()
    this.interval = setInterval(() => this.updateCountdown(), 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  updateCountdown() {
    const arrivalTime = new Date(this.arrivalValue)
    const now = new Date()
    const diff = arrivalTime - now

    if (diff <= 0) {
      this.element.textContent = "Arrived!"
      clearInterval(this.interval)
      
      if (this.refreshValue) {
        // Brief delay before refresh to show "Arrived!" message
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      }
      return
    }

    this.element.textContent = this.formatDuration(diff)
  }

  formatDuration(ms) {
    const totalSeconds = Math.floor(ms / 1000)
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    if (hours > 0) {
      return `${hours}h ${minutes}m ${seconds}s`
    } else if (minutes > 0) {
      return `${minutes}m ${seconds}s`
    } else {
      return `${seconds}s`
    }
  }
}
