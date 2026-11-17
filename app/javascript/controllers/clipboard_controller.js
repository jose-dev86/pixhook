import { Controller } from "@hotwired/stimulus"

// Copies the Pix "copia e cola" code and gives visual feedback on the button.
// Falls back to execCommand when the async Clipboard API is unavailable (older browsers, http).
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copied: String }

  async copy() {
    const text = this.sourceTarget.value

    try {
      await navigator.clipboard.writeText(text)
    } catch {
      this.sourceTarget.select()
      document.execCommand("copy")
    }

    this.showFeedback()
  }

  showFeedback() {
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedValue
    setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
  }
}
