class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: {
    admin: 0,
    lead: 1,
    developer: 2,
    analyst: 3,
    viewer: 4,
    client: 5
  }

  belongs_to :client, optional: true
  has_many :assigned_agenda_items, class_name: 'AgendaItem', foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :agenda_messages, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :notifications, dependent: :destroy

  after_initialize :set_default_role, if: :new_record?

  validates :first_name, :last_name, presence: true, length: { maximum: 50 }
  validates :time_zone, presence: true
  validates :client, presence: true, if: :client?

  scope :active, -> { where(active: true) }

  def full_name
    [first_name, last_name].reject(&:blank?).join(' ')
  end

  def short_name
    return email unless first_name.present?
    [first_name, last_name.presence && last_name.first].compact.join(' ')
  end

  def display_role
    role.titleize
  end

  def internal_role?
    admin? || lead? || developer? || analyst?
  end

  private

  def set_default_role
    self.role ||= :viewer
  end
end
