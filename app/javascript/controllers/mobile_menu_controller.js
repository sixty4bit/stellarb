import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  toggle() {
    const isOpen = !this.drawerTarget.classList.contains("-translate-x-full")
    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.drawerTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden", "md:overflow-auto")
  }

  close() {
    this.drawerTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden", "md:overflow-auto")
  }

  closeOnNav(event) {
    // Close drawer when a nav link is clicked
    if (event.target.closest("a")) {
      this.close()
    }
  }
}
