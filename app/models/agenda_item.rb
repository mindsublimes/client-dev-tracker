class AgendaItem < ApplicationRecord
  COMPLEXITY_OPTIONS = [
    ['Minimal', 1],
    ['Low', 2],
    ['Medium', 3],
    ['High', 4],
    ['Severe', 5]
  ].freeze

  COMPLEXITY_LABELS = COMPLEXITY_OPTIONS.map { |label, value| [value, label] }.to_h.freeze

  belongs_to :client
  belongs_to :project, optional: true
  belongs_to :sprint
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :instruction, optional: true

  has_many :agenda_messages, dependent: :destroy
  has_many :activity_logs, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :notifications, dependent: :destroy

  def active_timer_for(user)
    time_entries.where(user: user).active_timers.first
  end

  def has_active_timer_for?(user)
    active_timer_for(user).present?
  end

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
  validates :sprint, presence: true

  before_validation :sanitize_complexity
  before_validation :sync_hierarchy
  validate :hierarchy_consistency
  before_save :apply_rank_score
  after_save :notify_status_change, if: :saved_change_to_status?
  after_save :notify_assignment, if: :saved_change_to_assignee_id?

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

  def complexity_label
    COMPLEXITY_LABELS.fetch(complexity, 'Medium')
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

  def sync_hierarchy
    if sprint.present?
      self.project = sprint.project
      self.client = sprint.project.client if sprint.project&.client && client_id.blank?
    elsif project.present?
      self.client ||= project.client
    end
  end

  def hierarchy_consistency
    return unless client.present?

    if project.present? && project.client_id != client_id
      errors.add(:project_id, 'must belong to the selected client')
    end

    if sprint.present?
      errors.add(:sprint_id, 'must belong to the selected client') if sprint.project&.client_id != client_id
      errors.add(:sprint_id, 'must belong to the selected project') if project.present? && sprint.project_id != project_id
    end
  end

  def apply_rank_score
    AgendaItems::Ranker.new(self).apply
  end

  def notify_status_change
    old_status = saved_change_to_status? ? saved_change_to_status[0] : status_was
    new_status = status
    NotificationCreator.notify_status_change(self, old_status, new_status)
  end

  def notify_assignment
    return unless assignee.present?

    NotificationCreator.notify_assignment(self, assignee)
  end
end
