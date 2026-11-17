import { Controller } from "@hotwired/stimulus"

// Toggles between light and dark themes. The choice is stored per browser;
// without a stored choice the page follows the operating system preference.
export default class extends Controller {
  static values = { lightLabel: String, darkLabel: String }

  connect() {
    this.updateLabel()
  }

  toggle() {
    const next = this.currentTheme() === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = next
    try { localStorage.setItem("theme", next) } catch {}
    this.updateLabel()
  }

  currentTheme() {
    const chosen = document.documentElement.dataset.theme
    if (chosen) return chosen
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  updateLabel() {
    const label = this.currentTheme() === "dark" ? this.lightLabelValue : this.darkLabelValue
    this.element.setAttribute("aria-label", label)
    this.element.setAttribute("title", label)
  }
}
