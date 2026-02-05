import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Set up global keyboard shortcuts
    document.addEventListener('keydown', this.handleGlobalKeys.bind(this))
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleGlobalKeys.bind(this))
  }

  handleGlobalKeys(event) {
    // Don't capture keys when typing in inputs
    if (event.target.matches('input, textarea')) return

    switch(event.key) {
      case 'H':
        // Go home (Inbox)
        window.location.href = '/'
        break
      case '?':
        // Show keyboard help
        document.getElementById('keyboard-help').classList.toggle('hidden')
        break
    }
  }
}