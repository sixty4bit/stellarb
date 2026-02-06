import { Controller } from "@hotwired/stimulus"

// Syncs menu highlighting with current URL after Turbo Frame navigation
// Since Turbo Frames don't re-render the menu, this controller
// listens for navigation events and updates highlights client-side
//
// This controller manages the ACTIVE state (URL-based highlighting).
// The keyboard_navigation_controller manages SELECTED state (keyboard focus).
export default class extends Controller {
  static targets = ["item"]
  static classes = ["active", "activeText"]

  connect() {
    this.syncHighlight()
    
    // Listen for Turbo navigation events
    document.addEventListener("turbo:frame-load", this.boundSyncHighlight)
    document.addEventListener("turbo:render", this.boundSyncHighlight)
    window.addEventListener("popstate", this.boundSyncHighlight)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundSyncHighlight)
    document.removeEventListener("turbo:render", this.boundSyncHighlight)
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
      const span = link?.querySelector("span")
      const menuPath = link?.getAttribute("href")
      
      // Check if this menu item matches the current path
      const isActive = this.pathMatches(currentPath, menuPath)
      
      // Update visual state using data-menu-highlight-active-class or defaults
      const activeClass = this.hasActiveClass ? this.activeClass : "menu-active"
      const activeTextClass = this.hasActiveTextClass ? this.activeTextClass : "text-orange-500"
      
      if (isActive) {
        item.dataset.menuActive = "true"
        link?.classList.add(activeClass)
        if (span) span.classList.add(activeTextClass)
      } else {
        delete item.dataset.menuActive
        link?.classList.remove(activeClass)
        if (span) span.classList.remove(activeTextClass)
      }
    })
  }

  pathMatches(currentPath, menuPath) {
    if (!menuPath) return false
    
    // Normalize paths (remove trailing slashes)
    currentPath = currentPath.replace(/\/$/, '') || '/'
    menuPath = menuPath.replace(/\/$/, '') || '/'
    
    // Exact match
    if (currentPath === menuPath) return true
    
    // Don't match root path as prefix for everything
    if (menuPath === '/') return false
    
    // Handle nested routes (e.g., /ships/123 matches /ships menu)
    if (currentPath.startsWith(menuPath + "/")) return true
    
    return false
  }
}
