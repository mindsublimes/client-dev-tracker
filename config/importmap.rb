# Pin npm packages by running ./bin/importmap

pin "application"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js", preload: true
pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@5.3.3/dist/js/bootstrap.esm.js", preload: true
pin "select2", to: "https://ga.jspm.io/npm:select2@4.1.0-rc.0/dist/js/select2.min.js"
pin "select2/css", to: "https://ga.jspm.io/npm:select2@4.1.0-rc.0/dist/css/select2.min.css"
pin "flatpickr", to: "https://ga.jspm.io/npm:flatpickr@4.6.13/dist/flatpickr.js"
pin "flatpickr/css", to: "https://ga.jspm.io/npm:flatpickr@4.6.13/dist/flatpickr.css"
