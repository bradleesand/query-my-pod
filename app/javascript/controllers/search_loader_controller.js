import { Controller } from "@hotwired/stimulus"

// Displays a loading spinner while search is in progress
export default class extends Controller {
  static targets = ["spinner"]

  showSpinner() {
    this.spinnerTarget.classList.remove("d-none")
  }

  hideSpinner() {
    this.spinnerTarget.classList.add("d-none")
  }
}