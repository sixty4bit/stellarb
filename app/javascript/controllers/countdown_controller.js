import { Controller } from "@hotwired/stimulus"

/**
 * Countdown Controller
 * 
 * Displays a live countdown to a target timestamp.
 * When the countdown reaches zero, reloads the specified Turbo frame.
 * 
 * Usage:
 *   <span data-controller="countdown" 
 *         data-countdown-arrival-value="2026-02-05T20:30:00Z"
 *         data-countdown-frame-value="content_panel">
 *     Loading...
 *   </span>
 * 
 * Values:
 *   arrival: ISO 8601 timestamp of arrival
 *   frame: ID of the Turbo frame to reload on arrival (defaults to "content_panel")
 *   refresh: Whether to refresh on arrival (default: true)
 */
export default class extends Controller {
  static values = {
    arrival: String,     // ISO 8601 timestamp of arrival
    frame: { type: String, default: "content_panel" },  // Turbo frame to reload
    refresh: { type: Boolean, default: true }  // Whether to refresh on arrival
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
        setTimeout(() => this.reloadFrame(), 1000)
      }
      return
    }

    this.element.textContent = this.formatDuration(diff)
  }

  reloadFrame() {
    const frame = document.getElementById(this.frameValue)
    
    if (frame && frame.src) {
      // Reload the Turbo frame by reassigning its src
      frame.src = frame.src
    } else if (frame) {
      // Frame exists but has no src, use Turbo.visit to reload current page into frame
      Turbo.visit(window.location.href, { frame: this.frameValue })
    } else {
      // Fallback to full page reload if frame not found
      window.location.reload()
    }
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
