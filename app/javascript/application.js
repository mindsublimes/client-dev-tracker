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

function setupSprintSelectFiltering() {
  const sprintSelect = document.querySelector('[data-behavior="sprint-select"]')
  if (!sprintSelect) return

  const clientSelect = document.querySelector('[data-behavior="client-select"]')

  const filterOptions = () => {
    const clientId = clientSelect?.value || sprintSelect.dataset.clientId
    let hasVisible = false

    Array.from(sprintSelect.options).forEach(option => {
      if (!option.value) {
        option.hidden = false
        return
      }

      const matches = !clientId || option.dataset.clientId === clientId
      option.hidden = !matches
      if (matches) hasVisible = true
    })

    if (!clientId) {
      sprintSelect.value = ''
      sprintSelect.disabled = true
      return
    }

    sprintSelect.disabled = false
    if (!hasVisible || sprintSelect.selectedOptions[0]?.hidden) {
      sprintSelect.value = ''
    }
  }

  if (clientSelect) {
    clientSelect.addEventListener('change', () => {
      sprintSelect.dataset.clientId = clientSelect.value
      filterOptions()
      // Reinitialize Select2 after filtering
      if (window.jQuery && window.jQuery.fn.select2) {
        window.jQuery(sprintSelect).trigger('change.select2')
      }
    })
  }

  filterOptions()
}

function setupSelect2() {
  // Wait for jQuery and Select2 to be available
  if (typeof window.jQuery === 'undefined' || !window.jQuery.fn.select2) {
    // Retry after a short delay if Select2 isn't loaded yet
    setTimeout(setupSelect2, 100)
    return
  }

  const $ = window.jQuery

  // Destroy existing Select2 instances to avoid duplicates
  $('select.form-select:not([data-no-select2])').each(function() {
    if ($(this).hasClass('select2-hidden-accessible')) {
      $(this).select2('destroy')
    }
  })

  // Initialize Select2 on all select elements except those with data-no-select2
  $('select.form-select:not([data-no-select2])').each(function() {
    const select = this
    const $select = $(select)
    const $container = $select.closest('.col-md-3, .col-md-4, .col-md-6, .col-12, .col-lg-3, .col-lg-4, .col-lg-6')
    
    // Get the actual width of the select element's container
    const selectWidth = $select.outerWidth() || $select.parent().width() || '100%'

    $select.select2({
      width: '100%',
      dropdownAutoWidth: false,
      dropdownParent: $('body'), // Append to body to avoid overflow clipping
      allowClear: select.hasAttribute('data-allow-clear') || select.querySelector('option[value=""]'),
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

    // Ensure dropdown width matches select width exactly and position correctly
    $select.on('select2:open', function() {
      setTimeout(function() {
        const $dropdown = $('.select2-dropdown')
        const $container = $select.closest('.select2-container')
        if ($dropdown.length && $container.length) {
          const isMobile = window.innerWidth < 992
          const containerWidth = $container.outerWidth()
          const containerOffset = $container.offset()
          
          if (isMobile) {
            // On mobile, align dropdown with select field
            const selectFieldLeft = containerOffset.left
            const selectFieldWidth = $container.outerWidth()
            const viewportWidth = window.innerWidth
            // Convert 0.75rem to pixels (assuming 1rem = 16px)
            const marginPx = 12 // 0.75rem = 12px
            
            // Calculate if dropdown would overflow on the right
            const dropdownWidth = Math.min(selectFieldWidth, viewportWidth - marginPx * 2)
            let dropdownLeft = selectFieldLeft
            
            // If dropdown would overflow on the right, adjust it
            if (dropdownLeft + dropdownWidth > viewportWidth - marginPx) {
              dropdownLeft = viewportWidth - dropdownWidth - marginPx
            }
            
            // Ensure dropdown doesn't go beyond left margin
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
            // On desktop, match select width
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
    
    // Handle window resize
    $(window).on('resize', debounce(function() {
      if ($select.hasClass('select2-hidden-accessible')) {
        const $dropdown = $('.select2-dropdown')
        if ($dropdown.is(':visible')) {
          $select.trigger('select2:open')
        }
      }
    }, 250))

    // Handle form auto-submit if parent form has data-auto-submit
    const form = select.closest('form[data-auto-submit="true"]')
    if (form) {
      $select.on('select2:select select2:clear', function() {
        form.requestSubmit()
      })
    }
  })
}

// Reinitialize Select2 on Turbo navigation (if using Turbo)
document.addEventListener('turbo:load', setupSelect2)
document.addEventListener('turbo:render', setupSelect2)
