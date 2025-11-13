class AgendaMessage < ApplicationRecord
  belongs_to :agenda_item, touch: true
  belongs_to :user

  has_many_attached :files

  enum kind: { status_update: 0, comment: 1, issue: 2, decision: 3, question: 4, request: 5 }
  validates :body, presence: true

  scope :recent, -> { order(created_at: :desc) }

  after_commit :refresh_agenda_rank

  def label
    kind.titleize
  end

  private

  def refresh_agenda_rank
    agenda_item.refresh_rank!
  rescue ActiveRecord::RecordInvalid
    Rails.logger.debug("Agenda rank refresh skipped: #{agenda_item.errors.full_messages.join(', ')}")
  end
end
