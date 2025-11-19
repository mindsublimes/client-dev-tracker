// Basic interactions without Stimulus/Hotwire
import "bootstrap"

document.addEventListener('DOMContentLoaded', () => {
  setupAlertDismissals()
  setupNavToggle()
  setupAutoSubmitFilters()
  stripFilterParamsFromUrl()
  setupSidebarToggle()
  setupUserDropdown()
  setupImageModal()
  setupSprintSelectFiltering()
  setupSelect2()
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

function setupSidebarToggle() {
  const sidebar = document.getElementById('sidebar')
  const sidebarToggle = document.getElementById('sidebarToggle')
  const sidebarOverlay = document.getElementById('sidebarOverlay')

  if (!sidebar || !sidebarToggle) return

  // Toggle sidebar on button click
  sidebarToggle.addEventListener('click', () => {
    sidebar.classList.toggle('active')
    if (sidebarOverlay) {
      sidebarOverlay.classList.toggle('active')
    }
  })

  // Close sidebar when clicking overlay
  if (sidebarOverlay) {
    sidebarOverlay.addEventListener('click', () => {
      sidebar.classList.remove('active')
      sidebarOverlay.classList.remove('active')
    })
  }

  // Close sidebar when clicking a link (mobile only)
  const sidebarLinks = sidebar.querySelectorAll('.sidebar-link')
  sidebarLinks.forEach(link => {
    link.addEventListener('click', () => {
      if (window.innerWidth < 992) {
        sidebar.classList.remove('active')
        if (sidebarOverlay) {
          sidebarOverlay.classList.remove('active')
        }
      }
    })
  })

  // Handle window resize
  window.addEventListener('resize', () => {
    if (window.innerWidth >= 992) {
      sidebar.classList.remove('active')
      if (sidebarOverlay) {
        sidebarOverlay.classList.remove('active')
      }
    }
  })
}

function setupUserDropdown() {
  const dropdownButton = document.getElementById('userDropdown')
  const dropdownMenu = dropdownButton?.nextElementSibling

  if (!dropdownButton || !dropdownMenu) return

  // Toggle dropdown on button click
  dropdownButton.addEventListener('click', (e) => {
    e.preventDefault()
    e.stopPropagation()
    const isOpen = dropdownMenu.classList.contains('show')
    
    if (isOpen) {
      dropdownMenu.classList.remove('show')
      dropdownButton.setAttribute('aria-expanded', 'false')
      document.body.style.overflow = ''
    } else {
      dropdownMenu.classList.add('show')
      dropdownButton.setAttribute('aria-expanded', 'true')
      // Prevent body scroll when dropdown is open (only on mobile)
      if (window.innerWidth < 992) {
        document.body.style.overflow = 'hidden'
      }
    }
  })

  // Close dropdown when clicking outside
  document.addEventListener('click', (e) => {
    if (!dropdownButton.contains(e.target) && !dropdownMenu.contains(e.target)) {
      dropdownMenu.classList.remove('show')
      dropdownButton.setAttribute('aria-expanded', 'false')
      document.body.style.overflow = ''
    }
  })

  // Close dropdown when clicking on sign out
  const signOutButton = dropdownMenu.querySelector('form button, .dropdown-item')
  if (signOutButton) {
    signOutButton.addEventListener('click', () => {
      dropdownMenu.classList.remove('show')
      dropdownButton.setAttribute('aria-expanded', 'false')
      document.body.style.overflow = ''
    })
  }
}

function setupImageModal() {
  var imageModal = document.getElementById('imageModal');
  if (!imageModal) return;

  imageModal.addEventListener('show.bs.modal', function (event) {
    var button = event.relatedTarget;
    var fullImageUrl = button.getAttribute('data-full-image-url');
    var img = button.querySelector('img');
    var imageTitle = img ? img.alt : 'Image';

    var modalImage = imageModal.querySelector('#fullSizeImage');
    modalImage.src = fullImageUrl;
    modalImage.alt = imageTitle;

    var modalTitle = imageModal.querySelector('.modal-title');
    modalTitle.textContent = imageTitle;
  });
}

function cacheSprintOptions(sprintSelect) {
  if (sprintSelect._allSprintOptions) return

  sprintSelect._allSprintOptions = Array.from(sprintSelect.options).map(option => ({
    value: option.value,
    text: option.textContent,
    clientId: option.dataset.clientId || '',
    projectId: option.dataset.projectId || '',
    disabled: option.disabled
  }))
}

function rebuildSprintOptions(sprintSelect, options, selectedValue) {
  const fragment = document.createDocumentFragment()

  options.forEach(optionData => {
    const option = document.createElement('option')
    option.value = optionData.value
    option.textContent = optionData.text
    if (optionData.clientId) option.dataset.clientId = optionData.clientId
    if (optionData.projectId) option.dataset.projectId = optionData.projectId
    option.disabled = optionData.disabled
    option.selected = optionData.value === selectedValue
    fragment.appendChild(option)
  })

  sprintSelect.innerHTML = ''
  sprintSelect.appendChild(fragment)
}

function filterSprintOptions(sprintSelect, clientId) {
  if (!sprintSelect) return

  cacheSprintOptions(sprintSelect)
  const allOptions = sprintSelect._allSprintOptions || []

  const filteredOptions = allOptions.filter(option => {
    if (option.value === '') return true
    return clientId ? option.clientId === clientId : false
  })

  const previousValue = sprintSelect.value
  const hasVisible = filteredOptions.some(option => option.value)
  const shouldDisable = !clientId || !hasVisible
  const nextValue = filteredOptions.some(option => option.value === previousValue) ? previousValue : ''

  rebuildSprintOptions(sprintSelect, filteredOptions, nextValue)

  sprintSelect.disabled = shouldDisable
  sprintSelect.dataset.clientId = clientId || ''
  if (shouldDisable) {
    sprintSelect.value = ''
  }

  refreshSelect2ForElement(sprintSelect)
}

function refreshSelect2ForElement(select) {
  if (!isSelect2Ready()) return
  if (select.matches('[data-no-select2]')) return
  initializeSelect2(select)
}

function setupSprintSelectFiltering() {
  const sprintSelects = document.querySelectorAll('[data-behavior="sprint-select"]')
  if (!sprintSelects.length) return

  sprintSelects.forEach(sprintSelect => {
    const form = sprintSelect.closest('form')
    const clientSelect = form?.querySelector('[data-behavior="client-select"]')
    const initialClientId = clientSelect?.value || sprintSelect.dataset.clientId

    filterSprintOptions(sprintSelect, initialClientId)
    sprintSelect.dataset.sprintFilterInitialized = 'true'

    if (!clientSelect || clientSelect.dataset.sprintFilterListener === 'true') return

    const handleClientChange = () => {
      const clientId = clientSelect.value
      sprintSelect.dataset.clientId = clientId
      filterSprintOptions(sprintSelect, clientId)
    }

    clientSelect.addEventListener('change', handleClientChange)

    if (window.jQuery) {
      window.jQuery(clientSelect).on('select2:select select2:clear', handleClientChange)
    }

    clientSelect.dataset.sprintFilterListener = 'true'
  })
}

function setupSelect2() {
  if (!isSelect2Ready()) {
    setTimeout(setupSelect2, 100)
    return
  }

  document.querySelectorAll('select.form-select:not([data-no-select2])').forEach(select => {
    initializeSelect2(select)
  })
}

function isSelect2Ready() {
  return typeof window.jQuery !== 'undefined' &&
    typeof window.jQuery.fn !== 'undefined' &&
    typeof window.jQuery.fn.select2 === 'function'
}

function destroySelect2(select) {
  if (!isSelect2Ready()) return

  const $select = window.jQuery(select)
  $select.off('.select2Enhancements')

  if (select._select2ResizeHandler) {
    window.removeEventListener('resize', select._select2ResizeHandler)
    delete select._select2ResizeHandler
  }

  if ($select.hasClass('select2-hidden-accessible')) {
    $select.select2('destroy')
  }
}

function initializeSelect2(select) {
  if (!isSelect2Ready()) return
  if (select.matches('[data-no-select2]')) return

  const $ = window.jQuery
  const $select = $(select)

  destroySelect2(select)

  $select.select2({
    width: '100%',
    dropdownAutoWidth: false,
    dropdownParent: $('body'),
    allowClear: select.hasAttribute('data-allow-clear') || !!select.querySelector('option[value=""]'),
    placeholder: select.getAttribute('data-placeholder') || select.getAttribute('placeholder') || 'Select an option...',
    minimumResultsForSearch: select.hasAttribute('data-search-disabled') ? Infinity : 0,
    language: {
      noResults: function() {
        return 'No results found'
      },
      searching: function() {
        return 'Searching...'
      }
    }
  })

  $select.on('select2:open.select2Enhancements', function() {
    setTimeout(function() {
      const $dropdown = $('.select2-dropdown')
      const $container = $select.closest('.select2-container')
      if ($dropdown.length && $container.length) {
        const isMobile = window.innerWidth < 992
        const containerWidth = $container.outerWidth()
        const containerOffset = $container.offset()

        if (isMobile) {
          const selectFieldLeft = containerOffset.left
          const selectFieldWidth = $container.outerWidth()
          const viewportWidth = window.innerWidth
          const marginPx = 12

          const dropdownWidth = Math.min(selectFieldWidth, viewportWidth - marginPx * 2)
          let dropdownLeft = selectFieldLeft

          if (dropdownLeft + dropdownWidth > viewportWidth - marginPx) {
            dropdownLeft = viewportWidth - dropdownWidth - marginPx
          }

          if (dropdownLeft < marginPx) {
            dropdownLeft = marginPx
          }

          $dropdown.css({
            'width': dropdownWidth + 'px',
            'max-width': dropdownWidth + 'px',
            'min-width': dropdownWidth + 'px',
            'left': dropdownLeft + 'px',
            'right': 'auto',
            'top': (containerOffset.top + $container.outerHeight() + 4) + 'px',
            'z-index': 9999,
            'position': 'fixed'
          })
        } else {
          $dropdown.css({
            'width': containerWidth + 'px',
            'min-width': containerWidth + 'px',
            'max-width': containerWidth + 'px',
            'left': containerOffset.left + 'px',
            'top': (containerOffset.top + $container.outerHeight() + 4) + 'px',
            'z-index': 9999,
            'position': 'absolute'
          })
        }
      }
    }, 10)
  })

  const resizeHandler = debounce(function() {
    if ($select.hasClass('select2-hidden-accessible')) {
      const $dropdown = $('.select2-dropdown')
      if ($dropdown.is(':visible')) {
        $select.trigger('select2:open')
      }
    }
  }, 250)

  select._select2ResizeHandler = resizeHandler
  window.addEventListener('resize', resizeHandler)

  const form = select.closest('form[data-auto-submit="true"]')
  if (form) {
    $select.on('select2:select.select2Enhancements select2:clear.select2Enhancements', function() {
      form.requestSubmit()
    })
  }
}

// Reinitialize Select2 on Turbo navigation (if using Turbo)
document.addEventListener('turbo:load', setupSelect2)
document.addEventListener('turbo:render', setupSelect2)
document.addEventListener('turbo:load', setupSprintSelectFiltering)
document.addEventListener('turbo:render', setupSprintSelectFiltering)
