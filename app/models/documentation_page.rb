# frozen_string_literal: true

class DocumentationPage < ApplicationRecord
  belongs_to :project

  validates :title, presence: true, length: { maximum: 200 }
  validates :slug, presence: true, format: { with: /\A[a-z0-9][a-z0-9\-]*\z/ }
  validates :slug, uniqueness: { scope: :project_id }
end
