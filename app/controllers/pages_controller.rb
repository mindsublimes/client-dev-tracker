class PagesController < ApplicationController
  before_action :set_project
  before_action :set_page, only: %i[show edit update]

  def index
    authorize Page
    @pages = policy_scope(Page).where(project: @project).order(:title)
  end

  def show
    authorize @page
    @instructions = @page.instructions.order(:title)
  end

  def new
    @page = @project.pages.build
    authorize @page
  end

  def create
    @page = @project.pages.build(page_params)
    authorize @page

    if @page.save
      redirect_to project_page_path(@project, @page), success: 'Page created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @page
  end

  def update
    authorize @page

    if @page.update(page_params)
      redirect_to project_page_path(@project, @page), success: 'Page updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
  end

  def set_page
    @page = policy_scope(Page).where(project: @project).find(params[:id])
  end

  def page_params
    params.require(:page).permit(:title, :url, :description, :image)
  end
end
