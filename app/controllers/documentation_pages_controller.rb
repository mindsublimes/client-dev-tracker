# frozen_string_literal: true

class DocumentationPagesController < ApplicationController
  before_action :set_project
  before_action :set_page, only: :show

  def index
    authorize @project, :show?

    @pages = @project.documentation_pages.order(:slug)
  end

  def show
    authorize @project, :show?
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
  end

  def set_page
    @page = @project.documentation_pages.find_by!(slug: params[:id])
  end
end
