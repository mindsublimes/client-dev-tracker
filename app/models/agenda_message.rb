class AgendaMessage < ApplicationRecord
  belongs_to :agenda_item, touch: true
  belongs_to :user

  has_many_attached :files

  enum kind: { status_update: 0, comment: 1, issue: 2, decision: 3, question: 4, request: 5 }
  
  validate :body_or_files_present

  scope :recent, -> { order(created_at: :desc) }

  after_commit :refresh_agenda_rank
  after_commit :notify_message

  def label
    kind.titleize
  end

  private

  def body_or_files_present
    if body.blank? && !files.attached?
      errors.add(:base, 'Please either write a note or attach a file.')
    end
  end

  def refresh_agenda_rank
    agenda_item.refresh_rank!
  rescue ActiveRecord::RecordInvalid
    Rails.logger.debug("Agenda rank refresh skipped: #{agenda_item.errors.full_messages.join(', ')}")
  end

  def notify_message
    NotificationCreator.notify_message(agenda_item, self)
  end
end
