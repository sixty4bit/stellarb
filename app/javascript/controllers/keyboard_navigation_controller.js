import { Controller } from "@hotwired/stimulus"

// VI-style keyboard navigation controller
// Supports two focus zones: menu sidebar and content panel
// Tab switches between zones, j/k navigates within current zone
export default class extends Controller {
  static targets = ["menuItem", "contentItem", "contentPanel"]

  connect() {
    this.focusZone = 'menu' // 'menu' or 'content'
    this.menuIndex = 0
    this.contentIndex = 0
    this.menuItems = this.menuItemTargets
    this.bindKeyboardEvents()
    this.bindTurboEvents()
    this.highlightCurrentMenuItem()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyDown)
    document.removeEventListener("turbo:frame-load", this.boundHighlight)
    document.removeEventListener("turbo:frame-load", this.boundContentRefresh)
    document.removeEventListener("turbo:visit", this.boundHighlight)
    window.removeEventListener("popstate", this.boundHighlight)
  }

  bindKeyboardEvents() {
    this.handleKeyDown = this.onKeyDown.bind(this)
    document.addEventListener("keydown", this.handleKeyDown)
  }

  bindTurboEvents() {
    // Re-sync selection after Turbo navigation
    this.boundHighlight = this.highlightCurrentMenuItem.bind(this)
    this.boundContentRefresh = this.refreshContentItems.bind(this)
    document.addEventListener("turbo:frame-load", this.boundHighlight)
    document.addEventListener("turbo:frame-load", this.boundContentRefresh)
    document.addEventListener("turbo:visit", this.boundHighlight)
    window.removeEventListener("popstate", this.boundHighlight)
  }

  get contentItems() {
    // Dynamically query content items since they change with Turbo navigation
    return Array.from(document.querySelectorAll('[data-keyboard-navigation-target="contentItem"]'))
  }

  refreshContentItems() {
    // Reset content index when content changes
    this.contentIndex = 0
    if (this.focusZone === 'content') {
      this.updateContentSelection()
    }
  }

  onKeyDown(event) {
    // Ignore if user is typing in an input field
    if (event.target.matches('input, textarea, select')) return

    switch(event.key) {
      case 'Tab':
        event.preventDefault()
        this.toggleFocusZone()
        break
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

  toggleFocusZone() {
    const contentItems = this.contentItems
    if (this.focusZone === 'menu' && contentItems.length > 0) {
      this.focusZone = 'content'
      this.clearMenuSelection()
      this.updateContentSelection()
    } else {
      this.focusZone = 'menu'
      this.clearContentSelection()
      this.updateMenuSelection()
    }
  }

  selectNext() {
    if (this.focusZone === 'menu') {
      this.menuIndex = Math.min(this.menuIndex + 1, this.menuItems.length - 1)
      this.updateMenuSelection()
    } else {
      const items = this.contentItems
      this.contentIndex = Math.min(this.contentIndex + 1, items.length - 1)
      this.updateContentSelection()
    }
  }

  selectPrevious() {
    if (this.focusZone === 'menu') {
      this.menuIndex = Math.max(this.menuIndex - 1, 0)
      this.updateMenuSelection()
    } else {
      this.contentIndex = Math.max(this.contentIndex - 1, 0)
      this.updateContentSelection()
    }
  }

  updateMenuSelection() {
    this.menuItems.forEach((item, index) => {
      if (index === this.menuIndex) {
        item.classList.add("bg-blue-800", "selected")
        item.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      } else {
        item.classList.remove("bg-blue-800", "selected")
      }
    })
  }

  updateContentSelection() {
    const items = this.contentItems
    items.forEach((item, index) => {
      if (index === this.contentIndex) {
        item.classList.add("content-focused")
        item.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      } else {
        item.classList.remove("content-focused")
      }
    })
  }

  clearMenuSelection() {
    this.menuItems.forEach(item => {
      item.classList.remove("bg-blue-800", "selected")
    })
  }

  clearContentSelection() {
    this.contentItems.forEach(item => {
      item.classList.remove("content-focused")
    })
  }

  // Legacy method for compatibility
  updateSelection() {
    this.updateMenuSelection()
  }

  activateSelected() {
    let selectedItem
    if (this.focusZone === 'menu') {
      selectedItem = this.menuItems[this.menuIndex]
    } else {
      selectedItem = this.contentItems[this.contentIndex]
    }

    if (selectedItem) {
      const link = selectedItem.matches('a') ? selectedItem : selectedItem.querySelector('a')
      if (link && link.href) {
        const frameId = link.dataset.turboFrame
        if (frameId) {
          Turbo.visit(link.href, { 
            frame: frameId,
            action: "advance"
          })
        } else {
          Turbo.visit(link.href, { action: "advance" })
        }
      } else if (selectedItem.matches('button')) {
        selectedItem.click()
      }
    }
  }

  goBack() {
    // If in content zone, switch back to menu first
    if (this.focusZone === 'content') {
      this.toggleFocusZone()
      return
    }

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

  highlightCurrentMenuItem() {
    const currentPath = window.location.pathname
    
    this.menuItems.forEach((item, index) => {
      const link = item.querySelector('a')
      if (link) {
        const linkPath = link.pathname
        const isMatch = currentPath === linkPath || 
                       (linkPath !== '/' && currentPath.startsWith(linkPath + '/'))
        
        if (isMatch) {
          this.menuIndex = index
        }
      }
    })
    
    if (this.focusZone === 'menu') {
      this.updateMenuSelection()
    }
  }

  // Called by menu items on hover to update selection
  selectItem(event) {
    const item = event.currentTarget
    const index = this.menuItems.indexOf(item)
    if (index !== -1) {
      this.focusZone = 'menu'
      this.clearContentSelection()
      this.menuIndex = index
      this.updateMenuSelection()
    }
  }

  // Called by content items on hover
  selectContentItem(event) {
    const item = event.currentTarget
    const items = this.contentItems
    const index = items.indexOf(item)
    if (index !== -1) {
      this.focusZone = 'content'
      this.clearMenuSelection()
      this.contentIndex = index
      this.updateContentSelection()
    }
  }
}
