class Sprint < ApplicationRecord
  belongs_to :project
  has_one :client, through: :project
  has_many :agenda_items, dependent: :nullify

  delegate :label, to: :project, prefix: true, allow_nil: true

  validates :project, presence: true
  validates :name, presence: true, length: { maximum: 120 }
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validate :end_date_after_start

  def label
    [project&.name, name].compact.join(' - ')
  end

  def detailed_label
    parts = []
    parts << label
    parts << goal if goal.present?
    parts << date_window if start_date.present? || end_date.present?
    parts.compact.join(' • ')
  end

  private

  def date_window
    if start_date.present? && end_date.present?
      "#{start_date.to_fs(:long)} - #{end_date.to_fs(:long)}"
    elsif start_date.present?
      "Starts #{start_date.to_fs(:long)}"
    elsif end_date.present?
      "Ends #{end_date.to_fs(:long)}"
    end
  end

  def end_date_after_start
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, 'must be after the start date')
  end
end
