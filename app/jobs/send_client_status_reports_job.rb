# frozen_string_literal: true

class SendClientStatusReportsJob < ApplicationJob
  queue_as :default

  def perform(since: 1.day.ago)
    ClientLiaison::StatusReporter.deliver_all_pending!(since: since)
  rescue StandardError => e
    Rails.logger.error("[SendClientStatusReportsJob] #{e.class}: #{e.message}")
    raise
  end
end
