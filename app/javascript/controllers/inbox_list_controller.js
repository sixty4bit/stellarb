import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.selectedIndex = 0
    this.highlightItem()
  }

  navigate(event) {
    // Only handle j/k/Enter keys
    if (!['j', 'k', 'Enter'].includes(event.key)) return

    event.preventDefault()

    switch(event.key) {
      case 'j':
        // Move down
        this.selectedIndex = Math.min(this.selectedIndex + 1, this.itemTargets.length - 1)
        this.highlightItem()
        break
      case 'k':
        // Move up
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.highlightItem()
        break
      case 'Enter':
        // Select current item
        this.itemTargets[this.selectedIndex].click()
        break
    }
  }

  highlightItem() {
    this.itemTargets.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('ring-2', 'ring-orange-500')
        item.scrollIntoView({ block: 'nearest' })
      } else {
        item.classList.remove('ring-2', 'ring-orange-500')
      }
    })
  }
}