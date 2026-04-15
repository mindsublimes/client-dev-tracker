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
  
  enum client_role: {
    user: 0,
    admin: 1
  }, _prefix: :client

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

  # Figma OAuth (Design → Tasks). Tokens are stored on the user; rotate secret in Figma if leaked.
  def figma_oauth_connected?
    figma_access_token.present?
  end

  def apply_figma_oauth_response!(data)
    exp_seconds = data["expires_in"]
    exp_at = exp_seconds.present? ? Time.current + exp_seconds.to_i.seconds : nil
    update!(
      figma_access_token: data["access_token"],
      figma_refresh_token: data["refresh_token"].presence || figma_refresh_token,
      figma_token_expires_at: exp_at
    )
  end

  def disconnect_figma!
    update!(figma_access_token: nil, figma_refresh_token: nil, figma_token_expires_at: nil)
  end

  def ensure_figma_access_token_fresh!
    return if figma_access_token.blank?
    return if figma_refresh_token.blank?
    # Refresh a few minutes before expiry
    return if figma_token_expires_at.blank? || figma_token_expires_at > 10.minutes.from_now

    data = Figma::Oauth.refresh(refresh_token: figma_refresh_token)
    apply_figma_oauth_response!(data)
  rescue Figma::Oauth::Error
    # Leave existing token; next API call may 403 — user can reconnect
    nil
  end

  private

  def set_default_role
    self.role ||= :viewer
  end
end
