class ActivityLogger
  TRACKED_ATTRIBUTES = %w[
    title description status work_stream priority_level complexity due_on started_on completed_at
    assignee_id requested_by requested_by_email estimated_cost paid notes client_id
  ].freeze

  class << self
    def log_creation(agenda_item, user)
      ActivityLog.create!(agenda_item:, user:, action: 'Agenda item created')
    end

    def log_changes(agenda_item, user)
      changes = agenda_item.saved_changes.slice(*TRACKED_ATTRIBUTES)
      changes.each do |attribute, (from, to)|
        next if from == to

        previous_value = humanize_value(attribute, from, agenda_item)
        new_value = humanize_value(attribute, to, agenda_item)

        ActivityLog.create!(
          agenda_item:,
          user:,
          field_name: attribute,
          previous_value:,
          new_value:,
          action: build_action(attribute, previous_value, new_value)
        )
      end
    end

    def log_message(message)
      ActivityLog.create!(
        agenda_item: message.agenda_item,
        user: message.user,
        action: "#{message.kind.titleize} added",
        field_name: 'message',
        new_value: message.body.to_s.truncate(120)
      )
    end

    private

    def build_action(attribute, previous, current)
      label = attribute.tr('_', ' ').titleize

      if previous.present? && current.present?
        "#{label} changed from #{previous} to #{current}"
      elsif current.present?
        "#{label} set to #{current}"
      elsif previous.present?
        "#{label} cleared from #{previous}"
      else
        "#{label} updated"
      end
    end

    def humanize_value(attribute, value, agenda_item)
      return '' if value.nil?

      if agenda_item.class.defined_enums.key?(attribute)
        enum_hash = agenda_item.class.defined_enums[attribute]
        key = enum_hash.key(value.is_a?(String) ? value : value.to_s)
        key = enum_hash.key(value) if key.nil? && value.is_a?(Integer)
        key ||= enum_hash.key(value.to_i) if value.respond_to?(:to_i)
        key ? key.tr('_', ' ').titleize : value.to_s
      elsif attribute.ends_with?('_id')
        association_name = attribute.sub(/_id\z/, '')
        associated = fetch_association_record(association_name, value)
        associated_name(associated)
      elsif attribute.ends_with?('_on') || value.is_a?(Date)
        value.to_date.strftime('%b %d, %Y')
      elsif value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
        value.strftime('%b %d, %Y %l:%M %p')
      elsif attribute.include?('cost')
        format('$%.2f', value)
      elsif !!value == value # boolean check
        value ? 'Yes' : 'No'
      else
        value.to_s
      end
    end

    def fetch_association_record(name, id)
      klass = name.camelize.safe_constantize
      klass&.find_by(id: id)
    rescue StandardError
      nil
    end

    def associated_name(record)
      return '' unless record

      if record.respond_to?(:full_name)
        record.full_name
      elsif record.respond_to?(:name)
        record.name
      else
        record.to_s
      end
    end
  end
end
