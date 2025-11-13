class AgendaItem < ApplicationRecord
  belongs_to :client
  belongs_to :assignee, class_name: 'User', optional: true

  has_many :agenda_messages, dependent: :destroy
  has_many :activity_logs, dependent: :destroy

  enum work_stream: { sprint: 0, correction: 1, enhancement: 2, training: 3, support: 4 }
  enum status: {
    backlog: 0,
    scoped: 1,
    in_progress: 2,
    blocked: 3,
    in_review: 4,
    completed: 5,
    archived: 6,
    cancelled: 7
  }
  enum priority_level: { low: 0, normal: 1, high: 2, urgent: 3 }

  validates :title, presence: true
  validates :work_stream, :status, :priority_level, presence: true
  validates :complexity, inclusion: { in: 1..5 }
  validates :estimated_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :sanitize_complexity
  before_save :apply_rank_score

  scope :ranked, -> { order(rank_score: :desc, due_on: :asc) }
  scope :pending, -> { where.not(status: %i[completed archived cancelled]) }
  scope :due_within, ->(timeframe) { where(due_on: Date.current..(Date.current + timeframe)) }

  def pending?
    !completed? && !archived?
  end

  def status_badge_color
    {
      'backlog' => 'secondary',
      'scoped' => 'info',
      'in_progress' => 'primary',
      'blocked' => 'danger',
      'in_review' => 'warning',
      'completed' => 'success',
      'archived' => 'dark',
      'cancelled' => 'secondary'
    }[status]
  end

  def priority_badge_color
    {
      'low' => 'secondary',
      'normal' => 'info',
      'high' => 'warning',
      'urgent' => 'danger'
    }[priority_level]
  end

  def due_state
    return :none if due_on.blank?
    return :overdue if due_on < Date.current
    return :due_today if due_on == Date.current
    return :due_soon if due_on <= Date.current + 3.days

    :scheduled
  end

  def refresh_rank!
    AgendaItems::Ranker.new(self).apply
    save(validate: false)
  end

  private

  def sanitize_complexity
    self.complexity ||= 3
  end

  def apply_rank_score
    AgendaItems::Ranker.new(self).apply
  end
end
