# frozen_string_literal: true

module Agents
  # Agent #4 (v1): compile agenda activity in the last window and email configured recipients.
  class DailyProgressDigest
    class Error < StandardError; end

    class << self
      def deliver!(since: 24.hours.ago)
        recipients = recipient_emails
        raise Error, "No recipients found. Add admin/lead users or set AGENTS_DAILY_DIGEST_RECIPIENTS." if recipients.empty?

        logs = ActivityLog.includes(agenda_item: { project: :client, sprint: [] })
                          .where("activity_logs.created_at >= ?", since)
                          .order(created_at: :desc)
                          .limit(400)

        messages = AgendaMessage.includes(agenda_item: { project: :client })
                                .where("agenda_messages.created_at >= ?", since)
                                .order(created_at: :desc)
                                .limit(200)

        if logs.none? && messages.none?
          Agents::DailyProgressMailer.with(
            since: since,
            rows: [],
            message_rows: [],
            recipients: recipients
          ).digest_email.deliver_now
          return { delivered: true, empty: true }
        end

        rows = logs.map do |log|
          item = log.agenda_item
          {
            at: log.created_at,
            project: item&.project&.name,
            client: item&.project&.client&.name,
            item: item&.title,
            actor: log.actor_name,
            detail: log.display_message
          }
        end

        message_rows = messages.map do |m|
          item = m.agenda_item
          {
            at: m.created_at,
            project: item&.project&.name,
            client: item&.project&.client&.name,
            item: item&.title,
            actor: m.user&.full_name || m.user&.email,
            detail: m.body.to_s.truncate(400)
          }
        end

        Agents::DailyProgressMailer.with(
          since: since,
          rows: rows,
          message_rows: message_rows,
          recipients: recipients
        ).digest_email.deliver_now

        { delivered: true, empty: false, activity_rows: rows.size, message_rows: message_rows.size }
      end

      private

      def recipient_emails
        # Primary behavior: admins/leads + client contacts touched in this digest window.
        internal = User.active.where(role: %i[admin lead]).pluck(:email)
        client_admins = User.active.client.client_admin.pluck(:email)
        fallback = ENV["AGENTS_DAILY_DIGEST_RECIPIENTS"].to_s.split(",").map(&:strip)
        (internal + client_admins + fallback).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      end
    end
  end
end
