// Basic interactions without Stimulus/Hotwire

document.addEventListener('DOMContentLoaded', () => {
  setupAlertDismissals()
  setupNavToggle()
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
