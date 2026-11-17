import { Controller } from "@hotwired/stimulus"

// Copies the Pix "copia e cola" code and gives visual feedback on the button.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copied: String }

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedValue
    setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
  }
}
