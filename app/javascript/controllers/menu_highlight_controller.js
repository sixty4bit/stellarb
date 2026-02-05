import { Controller } from "@hotwired/stimulus"

// Syncs menu highlighting with current URL after Turbo Frame navigation
// Since Turbo Frames don't re-render the menu, this controller
// listens for navigation events and updates highlights client-side
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.syncHighlight()
    
    // Listen for Turbo navigation events
    document.addEventListener("turbo:frame-load", this.boundSyncHighlight)
    document.addEventListener("turbo:visit", this.boundSyncHighlight)
    window.addEventListener("popstate", this.boundSyncHighlight)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundSyncHighlight)
    document.removeEventListener("turbo:visit", this.boundSyncHighlight)
    window.removeEventListener("popstate", this.boundSyncHighlight)
  }

  get boundSyncHighlight() {
    if (!this._boundSyncHighlight) {
      this._boundSyncHighlight = this.syncHighlight.bind(this)
    }
    return this._boundSyncHighlight
  }

  syncHighlight() {
    const currentPath = window.location.pathname
    
    this.itemTargets.forEach(item => {
      const link = item.querySelector("a")
      const span = item.querySelector("span")
      const menuPath = link?.getAttribute("href")
      
      // Check if this menu item matches the current path
      const isActive = this.pathMatches(currentPath, menuPath)
      
      // Update visual state
      if (isActive) {
        item.classList.add("bg-blue-800")
        if (span) span.classList.add("text-orange-500")
      } else {
        item.classList.remove("bg-blue-800")
        if (span) span.classList.remove("text-orange-500")
      }
    })
  }

  pathMatches(currentPath, menuPath) {
    if (!menuPath) return false
    
    // Exact match
    if (currentPath === menuPath) return true
    
    // Handle nested routes (e.g., /ships/123 matches /ships menu)
    // But don't match /ships with /systems
    if (currentPath.startsWith(menuPath + "/")) return true
    
    return false
  }
}
