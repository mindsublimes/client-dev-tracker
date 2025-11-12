// Basic interactions without Stimulus/Hotwire

document.addEventListener('DOMContentLoaded', () => {
  setupAlertDismissals()
  setupNavToggle()
  setupAutoSubmitFilters()
  stripFilterParamsFromUrl()
})

function setupAlertDismissals() {
  document.querySelectorAll('[data-dismiss="alert"]').forEach((button) => {
    button.addEventListener('click', () => {
      const alert = button.closest('.alert')
      if (alert) {
        alert.classList.add('fade-out')
        setTimeout(() => alert.remove(), 200)
      }
    })
  })
}

function setupNavToggle() {
  const toggler = document.querySelector('[data-toggle="nav"]')
  if (!toggler) return

  toggler.addEventListener('click', () => {
    const targetSelector = toggler.getAttribute('data-target')
    const target = document.querySelector(targetSelector)
    if (target) {
      target.classList.toggle('show')
    }
  })
}

function setupAutoSubmitFilters() {
  document.querySelectorAll('form[data-auto-submit="true"]').forEach((form) => {
    const submit = () => form.requestSubmit()

    form.querySelectorAll('select, input[type="date"]').forEach((input) => {
      input.addEventListener('change', submit)
    })

    form.querySelectorAll('input[type="text"], input[type="search"]').forEach((input) => {
      input.addEventListener('input', debounce(submit, 400))
    })
  })
}

function debounce(callback, delay) {
  let timer
  return (...args) => {
    window.clearTimeout(timer)
    timer = window.setTimeout(() => callback.apply(null, args), delay)
  }
}

function stripFilterParamsFromUrl() {
  if (window.location.search.length > 0) {
    window.history.replaceState({}, document.title, window.location.pathname)
  }
}
