# frozen_string_literal: true

# Payment reminder emails (7 / 14 / 30 days) for open invoices — see ProcessPaymentReminderJob.
#
# Install on a server with cron (app user, from app root):
#   bundle exec whenever --update-crontab dev_tracker
# Production example:
#   bundle exec whenever --update-crontab dev_tracker --set "environment=production"
# List what would be written:
#   bundle exec whenever
#
# Heroku / Render / Fly: platform schedulers do not use this file — add daily jobs that run:
#   bundle exec rake financial:send_payment_reminders
#   bundle exec rake agents:daily_digest
#   bundle exec rake agents:refresh_docs
#
# Time is interpreted in the server’s local timezone unless you set TZ in crontab or here via env.

every 1.day, at: "8:00 am" do
  rake "financial:send_payment_reminders"
end

every 1.day, at: "8:15 am" do
  rake "agents:daily_digest"
end

every 1.day, at: "8:30 am" do
  rake "agents:refresh_docs"
end
