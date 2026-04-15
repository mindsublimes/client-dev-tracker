# frozen_string_literal: true

module Agents
  class DailyProgressDigestJob < ApplicationJob
    queue_as :default

    def perform(since: nil)
      since ||= 24.hours.ago
      Agents::DailyProgressDigest.deliver!(since: since)
    rescue Agents::DailyProgressDigest::Error => e
      Rails.logger.error("[Agents::DailyProgressDigestJob] #{e.message}")
    end
  end
end
