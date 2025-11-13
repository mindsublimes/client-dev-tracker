class ActivityLog < ApplicationRecord
  belongs_to :agenda_item
  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def actor_name
    user&.full_name || 'System'
  end

  def display_message
    if field_name.present?
      attr_label = field_name.tr('_', ' ').titleize
      if previous_value.present? && new_value.present?
        "#{attr_label} changed from #{previous_value} to #{new_value}"
      elsif new_value.present?
        "#{attr_label} set to #{new_value}"
      elsif previous_value.present?
        "#{attr_label} cleared from #{previous_value}"
      else
        action
      end
    else
      action
    end
  end
end
