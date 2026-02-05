import { Controller } from "@hotwired/stimulus"

// VI-style keyboard navigation controller
export default class extends Controller {
  static targets = ["menuItem", "contentPanel"]

  connect() {
    this.selectedIndex = 0
    this.menuItems = this.menuItemTargets
    this.bindKeyboardEvents()
    this.highlightCurrentMenuItem()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyDown)
  }

  bindKeyboardEvents() {
    // Store bound function so we can remove it later
    this.handleKeyDown = this.onKeyDown.bind(this)
    document.addEventListener("keydown", this.handleKeyDown)
  }

  onKeyDown(event) {
    // Ignore if user is typing in an input field
    if (event.target.matches('input, textarea, select')) return

    switch(event.key) {
      case 'j':
        event.preventDefault()
        this.selectNext()
        break
      case 'k':
        event.preventDefault()
        this.selectPrevious()
        break
      case 'Enter':
        event.preventDefault()
        this.activateSelected()
        break
      case 'Escape':
      case 'q':
        event.preventDefault()
        this.goBack()
        break
      case 'H':
        event.preventDefault()
        this.goHome()
        break
      case '?':
        event.preventDefault()
        this.showHelp()
        break
      case '/':
        event.preventDefault()
        this.focusSearch()
        break
    }
  }

  selectNext() {
    this.selectedIndex = Math.min(this.selectedIndex + 1, this.menuItems.length - 1)
    this.updateSelection()
  }

  selectPrevious() {
    this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
    this.updateSelection()
  }

  updateSelection() {
    this.menuItems.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add("bg-blue-800", "selected")
        item.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      } else {
        item.classList.remove("bg-blue-800", "selected")
      }
    })
  }

  activateSelected() {
    const selectedItem = this.menuItems[this.selectedIndex]
    if (selectedItem) {
      const link = selectedItem.querySelector('a') || selectedItem
      if (link.href) {
        // For Turbo Frame navigation
        if (link.dataset.turboFrame) {
          Turbo.visit(link.href, { frame: link.dataset.turboFrame })
        } else {
          link.click()
        }
      }
    }
  }

  goBack() {
    // Check if we're in a nested view by looking for breadcrumbs
    const breadcrumb = document.querySelector('.breadcrumb a:last-child')
    if (breadcrumb) {
      breadcrumb.click()
    } else if (window.history.length > 1) {
      window.history.back()
    }
  }

  goHome() {
    const homeLink = document.querySelector('a[href="/inbox"]')
    if (homeLink) {
      if (homeLink.dataset.turboFrame) {
        Turbo.visit(homeLink.href, { frame: homeLink.dataset.turboFrame })
      } else {
        homeLink.click()
      }
    }
  }

  showHelp() {
    const helpModal = document.getElementById('keyboard-help')
    if (helpModal) {
      helpModal.classList.remove('hidden')

      // Close on any key press
      const closeHelp = (e) => {
        e.preventDefault()
        helpModal.classList.add('hidden')
        document.removeEventListener('keydown', closeHelp)
      }

      setTimeout(() => {
        document.addEventListener('keydown', closeHelp)
      }, 100)
    }
  }

  focusSearch() {
    const searchInput = document.querySelector('input[type="search"], input[type="text"]')
    if (searchInput) {
      searchInput.focus()
    }
  }

  highlightCurrentMenuItem() {
    // Find the menu item matching the current path
    const currentPath = window.location.pathname
    this.menuItems.forEach((item, index) => {
      const link = item.querySelector('a')
      if (link && link.pathname === currentPath) {
        this.selectedIndex = index
        this.updateSelection()
      }
    })
  }

  // Called by menu items on hover to update selection
  selectItem(event) {
    const item = event.currentTarget
    const index = this.menuItems.indexOf(item)
    if (index !== -1) {
      this.selectedIndex = index
      this.updateSelection()
    }
  }
}