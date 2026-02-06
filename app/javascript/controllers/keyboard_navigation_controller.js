import { Controller } from "@hotwired/stimulus"

// VI-style keyboard navigation controller
// Manages SELECTED state (keyboard focus) separately from ACTIVE state (URL-based)
// The menu_highlight_controller manages which item is active based on URL
export default class extends Controller {
  static targets = ["menuItem", "contentPanel"]

  connect() {
    this.selectedIndex = -1 // Start with no selection until user navigates
    this.menuItems = this.menuItemTargets
    this.bindKeyboardEvents()
    this.bindTurboEvents()
    this.syncSelectionToActive()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyDown)
    document.removeEventListener("turbo:frame-load", this.boundSync)
    document.removeEventListener("turbo:render", this.boundSync)
    window.removeEventListener("popstate", this.boundSync)
  }

  bindKeyboardEvents() {
    this.handleKeyDown = this.onKeyDown.bind(this)
    document.addEventListener("keydown", this.handleKeyDown)
  }

  bindTurboEvents() {
    this.boundSync = this.syncSelectionToActive.bind(this)
    document.addEventListener("turbo:frame-load", this.boundSync)
    document.addEventListener("turbo:render", this.boundSync)
    window.addEventListener("popstate", this.boundSync)
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
    if (this.selectedIndex === -1) {
      // First navigation - start from active item or first item
      this.selectedIndex = this.findActiveIndex()
    }
    this.selectedIndex = Math.min(this.selectedIndex + 1, this.menuItems.length - 1)
    this.updateSelection()
  }

  selectPrevious() {
    if (this.selectedIndex === -1) {
      // First navigation - start from active item or first item
      this.selectedIndex = this.findActiveIndex()
    }
    this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
    this.updateSelection()
  }

  findActiveIndex() {
    // Find the currently active menu item (set by menu_highlight_controller)
    const activeIndex = this.menuItems.findIndex(item => item.dataset.menuActive === "true")
    return activeIndex !== -1 ? activeIndex : 0
  }

  updateSelection() {
    this.menuItems.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add("ring-2", "ring-orange-400", "ring-inset")
        item.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      } else {
        item.classList.remove("ring-2", "ring-orange-400", "ring-inset")
      }
    })
  }

  clearSelection() {
    this.menuItems.forEach(item => {
      item.classList.remove("ring-2", "ring-orange-400", "ring-inset")
    })
    this.selectedIndex = -1
  }

  activateSelected() {
    // If nothing selected, use the active item
    if (this.selectedIndex === -1) {
      this.selectedIndex = this.findActiveIndex()
    }
    
    const selectedItem = this.menuItems[this.selectedIndex]
    if (selectedItem) {
      const link = selectedItem.querySelector('a') || selectedItem
      if (link.href) {
        const frameId = link.dataset.turboFrame
        if (frameId) {
          Turbo.visit(link.href, { 
            frame: frameId,
            action: "advance"
          })
        } else {
          Turbo.visit(link.href, { action: "advance" })
        }
      }
    }
  }

  goBack() {
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
      const frameId = homeLink.dataset.turboFrame
      if (frameId) {
        Turbo.visit(homeLink.href, { 
          frame: frameId,
          action: "advance"
        })
      } else {
        Turbo.visit(homeLink.href, { action: "advance" })
      }
    }
  }

  showHelp() {
    const helpModal = document.getElementById('keyboard-help')
    if (helpModal) {
      helpModal.classList.remove('hidden')

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

  syncSelectionToActive() {
    // After navigation, clear keyboard selection and let active state show through
    this.clearSelection()
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
