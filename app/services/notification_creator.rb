class NotificationCreator
  class << self
    def notify_assignment(agenda_item, assignee)
      return unless assignee.present?
      return unless agenda_item.assignee_id == assignee.id

      # Don't notify if assignee is a client and this isn't their client's item
      return if assignee.client? && agenda_item.client_id != assignee.client_id

      Notification.create!(
        user: assignee,
        agenda_item: agenda_item,
        notification_type: :assigned,
        message: "You have been assigned to: #{agenda_item.title}"
      )
    end

    def notify_message(agenda_item, message)
      return if message.user.nil?

      # Determine who should be notified
      users_to_notify = []

      # If there's an assignee and it's not the message creator
      if agenda_item.assignee.present? && agenda_item.assignee_id != message.user_id
        # Only notify if assignee is a developer (they should see messages on their assigned items)
        # or if assignee is internal role (admin, lead, analyst)
        if agenda_item.assignee.developer? || agenda_item.assignee.internal_role?
          users_to_notify << agenda_item.assignee
        end
      end

      # If it's a client's agenda item, notify the client users (but not the message creator)
      if agenda_item.client.present?
        client_users = User.where(client_id: agenda_item.client_id, role: :client)
        client_users.each do |client_user|
          next if client_user.id == message.user_id
          users_to_notify << client_user
        end
      end

      # Create notifications
      users_to_notify.each do |user|
        Notification.create!(
          user: user,
          agenda_item: agenda_item,
          notification_type: :message,
          message: "#{message.user.full_name} posted a #{message.kind.titleize} on: #{agenda_item.title}"
        )
      end
    end

    def notify_status_change(agenda_item, old_status, new_status)
      return if old_status == new_status

      # Notify assignee if present (only if they're a developer or internal role)
      if agenda_item.assignee.present?
        if agenda_item.assignee.developer? || agenda_item.assignee.internal_role?
          Notification.create!(
            user: agenda_item.assignee,
            agenda_item: agenda_item,
            notification_type: :status_changed,
            message: "Status changed to #{new_status.titleize} on: #{agenda_item.title}"
          )
        end
      end

      # Notify client users if present
      if agenda_item.client.present?
        client_users = User.where(client_id: agenda_item.client_id, role: :client)
        client_users.each do |client_user|
          Notification.create!(
            user: client_user,
            agenda_item: agenda_item,
            notification_type: :status_changed,
            message: "Status changed to #{new_status.titleize} on: #{agenda_item.title}"
          )
        end
      end
    end
  end
end

