namespace :financial do
  desc "Send 7 / 14 / 30 day payment reminder emails for open invoices"
  task send_payment_reminders: :environment do
    ProcessPaymentReminderJob.perform_now
  end
end
