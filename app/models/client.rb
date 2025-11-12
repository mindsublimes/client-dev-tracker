class Client < ApplicationRecord
  has_many :agenda_items, dependent: :destroy

  enum priority_level: { standard: 0, elevated: 1, strategic: 2 }
  enum status: { active: 0, onboarding: 1, paused: 2, inactive: 3 }

  validates :name, :code, presence: true
  validates :code, uniqueness: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :ordered, -> { order(:name) }

  def primary_contact
    [contact_name, contact_email].compact.join(' • ')
  end
end
