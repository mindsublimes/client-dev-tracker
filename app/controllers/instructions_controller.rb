class InstructionsController < ApplicationController
  before_action :set_page
  before_action :set_instruction, only: %i[show edit update]

  def show
    authorize @instruction
    respond_to do |format|
      format.html
      format.json { render json: { instruction: instruction_json } }
    end
  end

  def new
    @instruction = @page.instructions.build
    authorize @instruction
  end

  def create
    @instruction = @page.instructions.build(instruction_params)
    authorize @instruction

    if @instruction.save
      redirect_to project_page_instruction_path(@page.project, @page, @instruction), success: 'Instruction created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @instruction
  end

  def update
    authorize @instruction

    if @instruction.update(instruction_params)
      redirect_to project_page_instruction_path(@page.project, @page, @instruction), success: 'Instruction updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_page
    @page = policy_scope(Page).find(params[:page_id])
  end

  def set_instruction
    @instruction = policy_scope(Instruction).where(page: @page).find(params[:id])
  end

  def instruction_params
    permitted = params.require(:instruction).permit(:title, :description, :image, :dots_data)
    # Handle dots_data - it comes as a JSON string from the form
    if permitted[:dots_data].present?
      begin
        permitted[:dots_data] = JSON.parse(permitted[:dots_data])
      rescue JSON::ParserError
        permitted[:dots_data] = []
      end
    else
      permitted[:dots_data] = []
    end
    permitted
  end

  def instruction_json
    {
      id: @instruction.id,
      title: @instruction.title,
      description: @instruction.description,
      image_url: @instruction.image.attached? ? url_for(@instruction.image) : nil,
      dots_data: @instruction.dots_data || []
    }
  end
end
