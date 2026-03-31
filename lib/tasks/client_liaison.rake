namespace :client_liaison do
  desc "Send client-friendly status updates for newly completed items"
  task send_daily_updates: :environment do
    delivered = ClientLiaison::StatusReporter.deliver_all_pending!(since: 1.day.ago)
    puts "Delivered updates for #{delivered} completed item(s)."
  end
end
