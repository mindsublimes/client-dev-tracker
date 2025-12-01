class Instruction < ApplicationRecord
  belongs_to :page
  has_many :agenda_items, dependent: :nullify
  has_one_attached :image

  validates :title, presence: true

  # dots_data structure: [{ x: 10, y: 20, blurb: "This is the search bar..." }, ...]
  # x and y are percentages (0-100) relative to image dimensions
end

