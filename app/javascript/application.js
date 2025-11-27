// Basic interactions without Stimulus/Hotwire
import "bootstrap"
import flatpickr from "flatpickr"

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
  setupBrowserNotifications()
  setupDateRangePicker()
  setupBulkAgendaForm()
  setupClientRoleField()
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
  
  // If no sprint is currently selected and we have options, select the first (latest) one
  let nextValue = ''
  if (hasVisible) {
    if (previousValue && filteredOptions.some(option => option.value === previousValue)) {
      // Keep the previously selected value if it's still available
      nextValue = previousValue
    } else {
      // Select the first available sprint (which should be the latest due to ordering)
      const firstAvailable = filteredOptions.find(option => option.value && !option.disabled)
      nextValue = firstAvailable ? firstAvailable.value : ''
    }
  }

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

  // Handle escape key and prevent Enter from submitting form
  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      searchResults.style.display = 'none'
      searchInput.blur()
    } else if (e.key === 'Enter') {
      e.preventDefault()
      e.stopPropagation()
      // Don't submit the form, just show dropdown results
    }
  })
  
  // Prevent form submission on Enter
  searchForm.addEventListener('submit', (e) => {
    e.preventDefault()
    return false
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
document.addEventListener('turbo:load', setupBrowserNotifications)
document.addEventListener('turbo:render', setupBrowserNotifications)
document.addEventListener('turbo:load', setupDateRangePicker)
document.addEventListener('turbo:render', setupDateRangePicker)
document.addEventListener('turbo:load', setupBulkAgendaForm)
document.addEventListener('turbo:render', setupBulkAgendaForm)
document.addEventListener('turbo:load', setupClientRoleField)
document.addEventListener('turbo:render', setupClientRoleField)

function setupClientRoleField() {
  const roleSelect = document.querySelector('[data-behavior="user-role-select"]')
  const clientRoleField = document.getElementById('client-role-field')
  
  if (!roleSelect || !clientRoleField) return
  
  function toggleClientRoleField() {
    if (roleSelect.value === 'client') {
      clientRoleField.style.display = 'block'
    } else {
      clientRoleField.style.display = 'none'
    }
  }
  
  // Set initial state
  toggleClientRoleField()
  
  // Update on change
  roleSelect.addEventListener('change', toggleClientRoleField)
}

function setupBrowserNotifications() {
  // Request notification permission
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission()
  }

  // Get last notification ID from localStorage (persists across page refreshes)
  const getLastNotificationId = () => {
    const stored = localStorage.getItem('lastBrowserNotificationId')
    return stored ? parseInt(stored, 10) : null
  }

  const setLastNotificationId = (id) => {
    localStorage.setItem('lastBrowserNotificationId', id.toString())
  }

  // Check for new notifications periodically
  let lastNotificationId = getLastNotificationId()
  const notificationCheckInterval = 30000 // 30 seconds

  function checkForNewNotifications() {
    if (!('Notification' in window) || Notification.permission !== 'granted') {
      return
    }

    const userId = document.body.dataset.userId
    if (!userId) return

    fetch(`/notifications.json?unread_only=true&last_id=${lastNotificationId || ''}`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      credentials: 'same-origin'
    })
    .then(response => response.json())
    .then(data => {
      if (data.notifications && data.notifications.length > 0) {
        data.notifications.forEach(notification => {
          if (!lastNotificationId || notification.id > lastNotificationId) {
            showBrowserNotification(notification)
            lastNotificationId = Math.max(lastNotificationId || 0, notification.id)
            setLastNotificationId(lastNotificationId)
          }
        })
      }
    })
    .catch(error => {
      console.error('Error checking notifications:', error)
    })
  }

  function showBrowserNotification(notification) {
    if (Notification.permission === 'granted') {
      const notificationObj = new Notification('DevTracker Notification', {
        body: notification.message,
        icon: '/favicon.ico',
        tag: `notification-${notification.id}`,
        requireInteraction: false,
        badge: '/favicon.ico'
      })

      notificationObj.onclick = function() {
        window.focus()
        if (notification.agenda_item_id) {
          window.location.href = `/agenda_items/${notification.agenda_item_id}`
        }
        notificationObj.close()
      }

      // Auto close after 5 seconds
      setTimeout(() => {
        notificationObj.close()
      }, 5000)
    }
  }

  // Listen for when notifications are marked as read to update the last seen ID
  document.addEventListener('click', (e) => {
    // Check if user clicked on "mark all read" or a notification link
    const markAllReadBtn = e.target.closest('[href*="mark_all_read"], button[formaction*="mark_all_read"]')
    const notificationLink = e.target.closest('[data-behavior="notification-link"], .notification-item')
    
    if (markAllReadBtn || notificationLink) {
      // Update last notification ID to current max to prevent showing old notifications
      fetch('/notifications.json?unread_only=false', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin'
      })
      .then(response => response.json())
      .then(data => {
        if (data.notifications && data.notifications.length > 0) {
          const maxId = Math.max(...data.notifications.map(n => n.id))
          setLastNotificationId(maxId)
          lastNotificationId = maxId
        }
      })
      .catch(() => {
        // Silently fail
      })
    }
  })

  // Start checking for notifications
  if (Notification.permission === 'granted') {
    checkForNewNotifications()
    setInterval(checkForNewNotifications, notificationCheckInterval)
  } else if (Notification.permission === 'default') {
    // If permission is still default, try requesting again after a delay
    setTimeout(() => {
      if (Notification.permission === 'default') {
        Notification.requestPermission().then(permission => {
          if (permission === 'granted') {
            checkForNewNotifications()
            setInterval(checkForNewNotifications, notificationCheckInterval)
          }
        })
      }
    }, 2000)
  }
}

function setupBulkAgendaForm() {
  const container = document.getElementById('bulk-items-container');
  const addButton = document.getElementById('add-item-row');
  
  if (!container || !addButton) return;
  
  // Prevent multiple initializations
  if (addButton.dataset.initialized === 'true') return;
  addButton.dataset.initialized = 'true';
  
  let rowIndex = 0;

  function createItemRow() {
    const rowId = `item_${rowIndex++}`;
    const row = document.createElement('div');
    row.className = 'bulk-item-row mb-4 pb-4 border-bottom';
    row.dataset.rowId = rowId;
    
    const today = new Date().toISOString().split('T')[0];
    
    row.innerHTML = `
      <div class="row g-2 mb-2">
        <div class="col-md-2">
          <label class="form-label small">Title</label>
          <input type="text" name="items[][title]" class="form-control form-control-sm" placeholder="Item title" />
        </div>
        <div class="col-md-2">
          <label class="form-label small">Type</label>
          <select name="items[][work_stream]" class="form-select form-select-sm">
            <option value="sprint">Sprint</option>
            <option value="correction">Correction</option>
            <option value="enhancement">Enhancement</option>
            <option value="training">Training</option>
            <option value="support">Support</option>
          </select>
        </div>
        <div class="col-md-2">
          <label class="form-label small">Status</label>
          <select name="items[][status]" class="form-select form-select-sm">
            <option value="backlog">Backlog</option>
            <option value="scoped">Scoped</option>
            <option value="in_progress">In Progress</option>
            <option value="blocked">Blocked</option>
            <option value="in_review">In Review</option>
            <option value="completed">Completed</option>
            <option value="archived">Archived</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>
        <div class="col-md-2">
          <label class="form-label small">Priority</label>
          <select name="items[][priority_level]" class="form-select form-select-sm">
            <option value="low">Low</option>
            <option value="normal" selected>Normal</option>
            <option value="high">High</option>
            <option value="urgent">Urgent</option>
          </select>
        </div>
        <div class="col-md-2">
          <label class="form-label small">Complexity</label>
          <select name="items[][complexity]" class="form-select form-select-sm">
            <option value="1">Minimal</option>
            <option value="2">Low</option>
            <option value="3" selected>Medium</option>
            <option value="4">High</option>
            <option value="5">Severe</option>
          </select>
        </div>
        <div class="col-md-2">
          <label class="form-label small">Due Date</label>
          <input type="date" name="items[][due_on]" class="form-control form-control-sm date-input" value="${today}" />
          <button type="button" class="btn btn-sm btn-outline-danger mt-2 w-100 remove-row" style="display: none;">
            <i class="bi bi-trash"></i> Remove
          </button>
        </div>
      </div>
      <div class="row g-2">
        <div class="col-12">
          <label class="form-label small">Description</label>
          <textarea name="items[][description]" class="form-control form-control-sm" rows="2" placeholder="Item description (optional)"></textarea>
        </div>
      </div>
    `;
    
    container.appendChild(row);
    updateRemoveButtons();
    
    // Initialize flatpickr for date fields if available
    if (typeof flatpickr !== 'undefined') {
      const dateInput = row.querySelector('.date-input');
      if (dateInput && !dateInput._flatpickr) {
        flatpickr(dateInput, {
          dateFormat: 'Y-m-d',
          allowInput: true
        });
      }
    }
  }

  function updateRemoveButtons() {
    const rows = container.querySelectorAll('.bulk-item-row');
    rows.forEach((row) => {
      const removeBtn = row.querySelector('.remove-row');
      if (removeBtn) {
        removeBtn.style.display = rows.length > 1 ? 'block' : 'none';
      }
    });
  }

  function removeItemRow(event) {
    const row = event.target.closest('.bulk-item-row');
    if (row) {
      row.remove();
      updateRemoveButtons();
    }
  }

  // Add event listener to the button
  addButton.addEventListener('click', function(e) {
    e.preventDefault();
    createItemRow();
  });
  
  // Add event listener for remove buttons (delegation)
  container.addEventListener('click', function(e) {
    if (e.target.closest('.remove-row')) {
      e.preventDefault();
      removeItemRow(e);
    }
  });

  // Add initial row if container is empty
  if (container.children.length === 0) {
    createItemRow();
  }
  
  // Reinitialize sprint filtering if needed
  if (typeof setupSprintSelectFiltering === 'function') {
    setupSprintSelectFiltering();
  }
}

function setupDateRangePicker() {
  const dateFromInput = document.querySelector('[data-behavior="date-range-from"]')
  const dateToInput = document.querySelector('[data-behavior="date-range-to"]')
  
  if (!dateFromInput || !dateToInput) return
  
  // Skip if already initialized
  if (dateFromInput._flatpickr || dateToInput._flatpickr) return
  
  // Get min/max dates from form text hint or use defaults
  const formText = dateFromInput.closest('.input-group')?.nextElementSibling?.textContent
  let minDate = null
  let maxDate = null
  
  if (formText) {
    const match = formText.match(/Range: (.+?) - (.+)/)
    if (match) {
      try {
        minDate = new Date(match[1].trim())
        maxDate = new Date(match[2].trim())
      } catch (e) {
        // Use defaults if parsing fails
      }
    }
  }
  
  const dateFromPicker = flatpickr(dateFromInput, {
    dateFormat: 'Y-m-d',
    allowInput: true,
    minDate: minDate || undefined,
    maxDate: maxDate || undefined,
    onChange: function(selectedDates) {
      if (selectedDates.length > 0 && dateToPicker) {
        dateToPicker.set('minDate', selectedDates[0])
      }
    }
  })
  
  const dateToPicker = flatpickr(dateToInput, {
    dateFormat: 'Y-m-d',
    allowInput: true,
    minDate: minDate || undefined,
    maxDate: maxDate || undefined,
    onChange: function(selectedDates) {
      if (selectedDates.length > 0 && dateFromPicker) {
        dateFromPicker.set('maxDate', selectedDates[0])
      }
    }
  })
}
