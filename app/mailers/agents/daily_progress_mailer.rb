# frozen_string_literal: true

module Agents
  class DailyProgressMailer < ApplicationMailer
    def digest_email
      @since = params[:since]
      @rows = params[:rows] || []
      @message_rows = params[:message_rows] || []
      recipients = Array(params[:recipients]).map(&:to_s).map(&:strip).reject(&:blank?).uniq

      mail(
        to: recipients,
        subject: "Dev tracker — daily progress (#{Date.current})"
      )
    end
  end
end
