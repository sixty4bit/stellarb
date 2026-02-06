import { Controller } from "@hotwired/stimulus"

// Plays audio files on demand. Supports multiple trigger methods:
// - Direct play() action
// - Auto-play on connect (with autoplay value)
// - Turbo Stream integration for server-triggered sounds
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
    if (this.autoplayValue && this.hasSrcValue) {
      this.play()
    }
  }

  play() {
    if (!this.hasSrcValue) return

    const audio = new Audio(this.srcValue)
    audio.volume = Math.max(0, Math.min(1, this.volumeValue))
    audio.play().catch(error => {
      // Browser may block autoplay without user interaction
      console.debug("Audio play blocked:", error.message)
    })
  }

  // Play a specific sound by passing the path
  playSound(event) {
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
