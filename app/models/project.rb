class Project < ApplicationRecord
  belongs_to :client
  has_many :sprints, dependent: :destroy
  has_many :agenda_items, dependent: :nullify
  has_many :notes, through: :agenda_items, source: :agenda_messages

  validates :client, presence: true
  validates :name, presence: true, length: { maximum: 120 }
  validates :estimated_cost, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validate :end_date_after_start

  def label
    base = [name, formatted_date_range].compact.join(' • ')
    base.presence || "Project ##{id}"
  end

  private

  def formatted_date_range
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
