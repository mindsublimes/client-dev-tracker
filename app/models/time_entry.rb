class TimeEntry < ApplicationRecord
  belongs_to :user
  belongs_to :agenda_item

  validates :hours, numericality: { greater_than: 0 }, allow_nil: true
  validates :date, presence: true, unless: -> { start_time.present? && end_time.nil? } # Allow nil date for active timers
  validate :hours_or_timer_present
  validate :end_time_after_start_time

  scope :recent, -> { order(date: :desc, created_at: :desc) }
  scope :active_timers, -> { where.not(start_time: nil).where(end_time: nil) }

  def active?
    start_time.present? && end_time.nil?
  end

  def calculate_hours
    return hours if hours.present?
    return nil unless start_time.present? && end_time.present?

    hours_calculated = ((end_time - start_time) / 1.hour).round(2)
    # Ensure minimum of 0.25 hours (15 minutes) to pass validation
    hours_calculated > 0 ? hours_calculated : 0.25
  end

  def stop_timer!
    return unless active?

    self.end_time = Time.current
    calculated = calculate_hours
    if calculated.present? && calculated > 0
      self.hours = calculated
    else
      # If calculation fails or is invalid, set minimum 0.25 hours
      self.hours = 0.25
    end
    self.date ||= Date.current
    save!
  end

  private

  def hours_or_timer_present
    return if hours.present?
    return if start_time.present? # Timer started, hours will be calculated when stopped

    errors.add(:base, 'Either hours must be provided or timer must be started')
  end

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?
    return if end_time > start_time

    errors.add(:end_time, 'must be after start time')
  end
end

