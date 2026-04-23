// Copyright (c) 2026, Schweizer Alpen-Club. This file is part of
// hitobito_sac_cas and licensed under the Affero General Public License version 3
// or later. See the COPYING file at the top-level directory or at
// https://github.com/hitobito/hitobito_sac_cas.

import { Controller } from "@hotwired/stimulus"

const FIELDS = [
  "name", "summit", "ascent", "descent",
  "duration_h", "duration_m", "location",
  "description", "maps", "tourenportal_link"
]

export default class extends Controller {
  static targets = ["modal", "urlInput", "submitButton", "error", "spinner"]
  static values  = { endpoint: String }

  connect() {
    this.abortController = null
    this.lastSubmittedAt = 0
  }

  open(event) {
    if (event) event.preventDefault()
    this.clearError()
    this.modalTarget.classList.add("show")
    this.modalTarget.style.display = "block"
    this.urlInputTarget.focus()
  }

  close(event) {
    if (event) event.preventDefault()
    if (this.abortController) this.abortController.abort()
    this.abortController = null
    this.modalTarget.classList.remove("show")
    this.modalTarget.style.display = "none"
    this.urlInputTarget.value = ""
    this.clearError()
    this.setLoading(false)
  }

  clearError() {
    this.errorTarget.classList.add("d-none")
    this.errorTarget.textContent = ""
  }

  async submit(event) {
    if (event) event.preventDefault()
    const now = Date.now()
    if (now - this.lastSubmittedAt < 1000) return
    this.lastSubmittedAt = now

    const url = this.urlInputTarget.value.trim()
    if (!url) return

    this.setLoading(true)
    this.clearError()
    this.abortController = new AbortController()

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ url }),
        credentials: "same-origin",
        signal: this.abortController.signal
      })
      const payload = await response.json()

      if (payload.status === "ok") {
        this.applyFields(payload.fields || {})
      } else {
        this.showError(payload.message || payload.code)
      }
    } catch (err) {
      if (err.name !== "AbortError") {
        this.showError(err.message)
      }
    } finally {
      this.setLoading(false)
      this.abortController = null
    }
  }

  applyFields(fields) {
    const keys = Object.keys(fields).filter(k => FIELDS.includes(k))
    const anyFilled = keys.some(k => {
      const input = this.findInput(k)
      return input && String(input.value || "").trim() !== ""
    })
    if (anyFilled && !window.confirm(this.overwriteConfirmText())) {
      return
    }
    keys.forEach(k => this.setInput(k, fields[k]))
    this.close()
  }

  findInput(key) {
    const form = this.element.closest("form")
    return form ? form.querySelector(`[name="event[${key}]"]`) : null
  }

  setInput(key, value) {
    const input = this.findInput(key)
    if (!input) return
    input.value = value == null ? "" : String(value)
    input.dispatchEvent(new Event("change", { bubbles: true }))
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  overwriteConfirmText() {
    return this.element.dataset.overwriteConfirmText ||
           "Die bestehenden Werte werden überschrieben. Fortfahren?"
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  setLoading(loading) {
    this.submitButtonTarget.disabled = loading
    this.spinnerTarget.classList.toggle("d-none", !loading)
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("d-none")
  }
}
