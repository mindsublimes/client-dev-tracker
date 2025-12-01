class Page < ApplicationRecord
  belongs_to :project
  has_many :instructions, dependent: :destroy
  has_one_attached :image

  validates :title, presence: true
  validates :url, presence: true
end

