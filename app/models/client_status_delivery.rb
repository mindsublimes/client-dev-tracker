class ClientStatusDelivery < ApplicationRecord
  belongs_to :client

  enum status: { sent: "sent", failed: "failed" }, _prefix: :delivery

  validates :status, presence: true
end
