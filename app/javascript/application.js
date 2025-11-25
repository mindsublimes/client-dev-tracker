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
  setupGlobalSearch()
  setupNotificationDropdown()
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

function setupGlobalSearch() {
  const searchForm = document.querySelector('[data-behavior="global-search"]')
  const searchInput = document.querySelector('[data-behavior="search-input"]')
  const searchResults = document.getElementById('searchResults')

  if (!searchForm || !searchInput || !searchResults) return

  let searchTimeout
  let currentRequest = null

  const positionSearchResults = () => {
    const searchInput = document.querySelector('[data-behavior="search-input"]')
    if (!searchInput || !searchResults) return

    const inputRect = searchInput.getBoundingClientRect()
    const inputGroup = searchInput.closest('.input-group')
    const inputGroupRect = inputGroup ? inputGroup.getBoundingClientRect() : inputRect

    // Calculate position to avoid sidebar (sidebar is 260px wide on desktop)
    const sidebarWidth = window.innerWidth >= 992 ? 260 : 0
    let leftPosition = inputGroupRect.left
    
    // Ensure dropdown doesn't overlap with sidebar
    if (leftPosition < sidebarWidth) {
      leftPosition = sidebarWidth + 10
    }

    searchResults.style.position = 'fixed'
    searchResults.style.top = (inputGroupRect.bottom + 4) + 'px'
    searchResults.style.left = leftPosition + 'px'
    searchResults.style.width = inputGroupRect.width + 'px'
    searchResults.style.maxWidth = inputGroupRect.width + 'px'
    searchResults.style.zIndex = '10001'
    searchResults.style.backgroundColor = '#fff'
    searchResults.style.background = '#fff'
    searchResults.style.opacity = '1'
    searchResults.style.visibility = 'visible'
    searchResults.style.mixBlendMode = 'normal'
    searchResults.style.overflow = 'hidden'
    searchResults.style.contain = 'layout style paint'
    
    // Ensure all child elements have white background
    const p2 = searchResults.querySelector('.p-2')
    if (p2) {
      p2.style.backgroundColor = '#fff'
      p2.style.background = '#fff'
      p2.style.position = 'relative'
      p2.style.zIndex = '1'
    }
    
    // Set background on all result items
    searchResults.querySelectorAll('.search-result-item').forEach(item => {
      item.style.backgroundColor = '#fff'
      item.style.background = '#fff'
    })
  }

  const performSearch = (query) => {
    if (currentRequest) {
      currentRequest.abort()
    }

    if (query.length < 2) {
      searchResults.style.display = 'none'
      return
    }

    positionSearchResults()
    searchResults.style.display = 'block'
    searchResults.querySelector('.p-2').innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm text-primary" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
      </div>
    `

    const url = new URL(searchForm.action, window.location.origin)
    url.searchParams.set('q', query)

    const xhr = new XMLHttpRequest()
    currentRequest = xhr

    xhr.open('GET', url.toString())
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
    xhr.setRequestHeader('Accept', 'text/html')
    xhr.setRequestHeader('X-Requested-Format', 'html')

    xhr.onload = () => {
      if (xhr.status === 200) {
        positionSearchResults()
        const p2 = searchResults.querySelector('.p-2')
        if (p2) {
          // Since controller renders with layout: false, response is already clean HTML
          p2.innerHTML = xhr.responseText.trim()
          p2.style.backgroundColor = '#fff'
          p2.style.background = '#fff'
          
          // Ensure all result items have white background
          p2.querySelectorAll('.search-result-item, *').forEach(item => {
            item.style.backgroundColor = '#fff'
            item.style.background = '#fff'
            item.style.mixBlendMode = 'normal'
          })
        }
      } else {
        positionSearchResults()
        const p2 = searchResults.querySelector('.p-2')
        if (p2) {
          p2.innerHTML = `
            <div class="text-center py-3 text-muted">
              Error loading results
            </div>
          `
          p2.style.backgroundColor = '#fff'
          p2.style.background = '#fff'
        }
      }
      currentRequest = null
    }

    xhr.onerror = () => {
      searchResults.querySelector('.p-2').innerHTML = `
        <div class="text-center py-3 text-muted">
          Error loading results
        </div>
      `
      currentRequest = null
    }

    xhr.send()
  }

  searchInput.addEventListener('input', (e) => {
    const query = e.target.value.trim()
    clearTimeout(searchTimeout)
    searchTimeout = setTimeout(() => performSearch(query), 300)
  })

  searchInput.addEventListener('focus', () => {
    const query = searchInput.value.trim()
    if (query.length >= 2) {
      positionSearchResults()
      performSearch(query)
    }
  })

  // Reposition on window resize
  window.addEventListener('resize', () => {
    if (searchResults.style.display === 'block') {
      positionSearchResults()
    }
  })

  // Reposition on scroll
  window.addEventListener('scroll', () => {
    if (searchResults.style.display === 'block') {
      positionSearchResults()
    }
  }, true)

  // Close search results when clicking outside
  document.addEventListener('click', (e) => {
    if (!searchForm.contains(e.target) && !searchResults.contains(e.target)) {
      searchResults.style.display = 'none'
    }
  })

  // Handle escape key
  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      searchResults.style.display = 'none'
      searchInput.blur()
    }
  })
}

function setupNotificationDropdown() {
  const notificationButton = document.getElementById('notificationDropdown')
  const notificationMenu = document.getElementById('notificationMenu')

  if (!notificationButton || !notificationMenu) return

  notificationButton.addEventListener('click', (e) => {
    e.preventDefault()
    e.stopPropagation()
    const isOpen = notificationMenu.classList.contains('show')
    
    if (isOpen) {
      notificationMenu.classList.remove('show')
      notificationButton.setAttribute('aria-expanded', 'false')
    } else {
      notificationMenu.classList.add('show')
      notificationButton.setAttribute('aria-expanded', 'true')
    }
  })

  // Close dropdown when clicking outside
  document.addEventListener('click', (e) => {
    if (!notificationButton.contains(e.target) && !notificationMenu.contains(e.target)) {
      notificationMenu.classList.remove('show')
      notificationButton.setAttribute('aria-expanded', 'false')
    }
  })

  // Handle notification link clicks
  document.querySelectorAll('[data-behavior="notification-link"]').forEach(link => {
    link.addEventListener('click', (e) => {
      // Allow the link to navigate, but mark as read via AJAX if needed
      const url = link.getAttribute('href')
      if (url) {
        fetch(url, {
          method: 'PATCH',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content'),
            'Accept': 'application/json'
          },
          credentials: 'same-origin'
        }).catch(() => {
          // Silently fail if AJAX doesn't work, let the normal link handle it
        })
      }
    })
  })
}

// Reinitialize Select2 on Turbo navigation (if using Turbo)
document.addEventListener('turbo:load', setupSelect2)
document.addEventListener('turbo:render', setupSelect2)
document.addEventListener('turbo:load', setupSprintSelectFiltering)
document.addEventListener('turbo:render', setupSprintSelectFiltering)
document.addEventListener('turbo:load', setupGlobalSearch)
document.addEventListener('turbo:render', setupGlobalSearch)
document.addEventListener('turbo:load', setupNotificationDropdown)
document.addEventListener('turbo:render', setupNotificationDropdown)
