import { Controller } from "@hotwired/stimulus"

// Plays audio files on demand. Supports multiple trigger methods:
// - Direct play() action
// - Auto-play on connect (with autoplay value)
// - Turbo Stream integration for server-triggered sounds
//
// Respects user sound preference:
// - Checks localStorage for 'soundEnabled' setting
// - Syncs with server-side preference via data attribute
//
// Usage:
//   <div data-controller="audio" data-audio-src-value="/sounds/notification.mp3"></div>
//   <button data-controller="audio" data-audio-src-value="/sounds/click.mp3" data-action="click->audio#play">Click</button>
//
export default class extends Controller {
  static values = {
    src: String,
    volume: { type: Number, default: 0.5 },
    autoplay: { type: Boolean, default: false }
  }

  connect() {
    // Sync localStorage with server preference on page load
    this.syncFromServer()
    
    if (this.autoplayValue && this.hasSrcValue) {
      this.play()
    }
  }

  // Check if sound is enabled (localStorage takes precedence for instant feedback)
  isSoundEnabled() {
    const stored = localStorage.getItem('soundEnabled')
    if (stored !== null) {
      return stored !== 'false'
    }
    // Default to true if not set
    return true
  }

  // Sync localStorage from server-side data attribute (on page load)
  syncFromServer() {
    const serverPref = document.body.dataset.soundEnabled
    if (serverPref !== undefined) {
      localStorage.setItem('soundEnabled', serverPref)
    }
  }

  // Called when user toggles the checkbox in settings
  syncPreference(event) {
    const enabled = event.target.checked
    localStorage.setItem('soundEnabled', enabled.toString())
  }

  play() {
    if (!this.hasSrcValue || !this.isSoundEnabled()) return

    const audio = new Audio(this.srcValue)
    audio.volume = Math.max(0, Math.min(1, this.volumeValue))
    audio.play().catch(error => {
      // Browser may block autoplay without user interaction
      console.debug("Audio play blocked:", error.message)
    })
  }

  // Play a specific sound by passing the path
  playSound(event) {
    if (!this.isSoundEnabled()) return
    
    const src = event.params?.src || event.detail?.src
    if (!src) return

    const volume = event.params?.volume || event.detail?.volume || this.volumeValue
    const audio = new Audio(src)
    audio.volume = Math.max(0, Math.min(1, volume))
    audio.play().catch(error => {
      console.debug("Audio play blocked:", error.message)
    })
  }
}
