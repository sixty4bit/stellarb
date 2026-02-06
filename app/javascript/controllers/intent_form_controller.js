import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="intent-form"
// Toggles price fields based on intent type selection
// Buy/Load intents show max_price field
// Sell/Unload intents show min_price field
export default class extends Controller {
  static targets = ["type", "maxPrice", "minPrice"]

  connect() {
    this.updatePriceFields()
  }

  typeChanged() {
    this.updatePriceFields()
  }

  updatePriceFields() {
    const type = this.typeTarget.value

    if (["buy", "load"].includes(type)) {
      this.showMaxPrice()
      this.hideMinPrice()
    } else if (["sell", "unload"].includes(type)) {
      this.hideMaxPrice()
      this.showMinPrice()
    } else {
      // No type selected - show both
      this.showMaxPrice()
      this.showMinPrice()
    }
  }

  showMaxPrice() {
    if (this.hasMaxPriceTarget) {
      this.maxPriceTarget.classList.remove("hidden")
      this.maxPriceTarget.disabled = false
    }
  }

  hideMaxPrice() {
    if (this.hasMaxPriceTarget) {
      this.maxPriceTarget.classList.add("hidden")
      this.maxPriceTarget.disabled = true
      this.maxPriceTarget.value = ""
    }
  }

  showMinPrice() {
    if (this.hasMinPriceTarget) {
      this.minPriceTarget.classList.remove("hidden")
      this.minPriceTarget.disabled = false
    }
  }

  hideMinPrice() {
    if (this.hasMinPriceTarget) {
      this.minPriceTarget.classList.add("hidden")
      this.minPriceTarget.disabled = true
      this.minPriceTarget.value = ""
    }
  }
}
