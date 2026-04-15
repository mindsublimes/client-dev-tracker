class ProjectsController < ApplicationController
  before_action :set_project, only: %i[
    show edit update refine_design_prompt
    figma_import figma_import_preview figma_import_create
    mark_design_payment_received
    run_designer_agent_wireframe run_developer_agent_from_spec
    run_designer_agent_figma_sync generate_documentation_agent
  ]
  before_action :set_form_collections, only: %i[new create edit update]

  def index
    authorize Project

    scope = policy_scope(Project).includes(:client)
    @filters = project_filter_params

    # For developers, only show projects associated with agenda items they're assigned to
    if current_user&.developer?
      assigned_project_ids = AgendaItem.where(assignee_id: current_user.id)
                                       .where.not(project_id: nil)
                                       .distinct
                                       .pluck(:project_id)
      scope = scope.where(id: assigned_project_ids)
    end

    scope = scope.where(client_id: @filters[:client_id]) if @filters[:client_id].present?
    if @filters[:search].present?
      term = "%#{@filters[:search]}%"
      scope = scope.where('projects.name ILIKE :term OR projects.description ILIKE :term', term:)
    end

    @projects = scope.order(created_at: :desc)
    @clients = clients_for_filter
  end

  def show
    authorize @project

    @sprints = @project.sprints.includes(agenda_items: :assignee).order(:start_date)
    @agenda_items = @project.agenda_items.includes(:sprint)

    @project_stats = build_project_stats(@agenda_items)
    @sprint_summaries = build_sprint_summaries(@sprints)
  end

  def new
    @project = Project.new(start_date: Date.current, end_date: Date.current + 30.days)
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    if @project.save
      redirect_to @project, success: 'Project created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project

    if @project.update(project_params)
      redirect_to @project, success: 'Project updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def refine_design_prompt
    authorize @project

    brief = params[:design_brief].presence || @project.design_brief
    if brief.blank?
      redirect_to project_path(@project), alert: 'Enter a design brief (markdown) first.'
      return
    end

    @project.update!(design_brief: brief)
    result = DesignPromptRefiner.call_with_meta(brief)
    @project.update!(design_prompt: result[:text])
    if result[:source] == :openai
      redirect_to project_path(@project), success: 'Prompt refined for Figma. Review it below, then open Figma Make and paste it when you are ready.'
    else
      redirect_to project_path(@project), warning: "Prompt could not be refined with AI (#{result[:error] || 'unknown issue'}). The raw brief is saved as the prompt — you can edit and refine again."
    end
  end

  def figma_import
    authorize @project, :figma_import?
    load_figma_import_collections
  end

  def figma_import_preview
    authorize @project, :figma_import?
    load_figma_import_collections

    file_key = extract_figma_file_key(params[:figma_url].presence || params[:figma_file_key].presence || @project.figma_file_key)
    if file_key.blank?
      flash.now[:alert] = 'Paste a Figma file or design URL, or enter a file key.'
      render :figma_import, status: :unprocessable_entity
      return
    end

    if ActiveModel::Type::Boolean.new.cast(params[:save_default_file_key])
      @project.update_column(:figma_file_key, file_key)
    end

    file_json = Figma::FileFetcher.fetch(file_key, user: current_user)
    frames = Figma::FrameCollector.collect_from_file(file_json)
    if frames.empty?
      flash.now[:alert] = 'No frames or components found in this file (or the file structure is empty).'
      @suggested_tasks = []
      render :figma_import, status: :unprocessable_entity
      return
    end

    @suggested_tasks = Figma::DesignTasksGenerator.call(
      frames: frames,
      project_name: @project.name,
      project_description: @project.description
    )
    @preview_file_key = file_key
    @frames_sample_count = frames.size
    flash.now[:success] = "Found #{frames.size} frame/component node(s); generated #{@suggested_tasks.size} suggested task(s)."
    render :figma_import
  rescue Figma::FileFetcher::MissingToken => e
    load_figma_import_collections
    flash.now[:alert] = e.message
    render :figma_import, status: :unprocessable_entity
  rescue Figma::FileFetcher::Unauthorized, Figma::FileFetcher::NotFound, Figma::FileFetcher::Error => e
    load_figma_import_collections
    flash.now[:alert] = e.message
    render :figma_import, status: :unprocessable_entity
  end

  def figma_import_create
    authorize @project, :figma_import?
    sprint = @project.sprints.find_by(id: params.dig(:figma_import, :sprint_id))
    unless sprint
      redirect_to figma_import_project_path(@project), alert: 'Choose a sprint that belongs to this project.'
      return
    end

    assignee_id = params.dig(:figma_import, :assignee_id).presence
    raw_tasks = params.dig(:figma_import, :tasks)
    rows = normalize_figma_task_rows(raw_tasks)

    selected = rows.select do |h|
      v = h['include'] || h[:include]
      v.to_s == '1' || v == true
    end

    if selected.empty?
      redirect_to figma_import_project_path(@project), alert: 'Select at least one task to create.'
      return
    end

    created = 0
    selected.each do |h|
      title = (h['title'] || h[:title]).to_s.strip
      next if title.blank?

      desc = (h['description'] || h[:description]).to_s.presence

      agenda_item = AgendaItem.new(
        client_id: @project.client_id,
        project_id: @project.id,
        sprint_id: sprint.id,
        assignee_id: assignee_id,
        title: title.truncate(255),
        description: desc,
        priority_level: :normal,
        work_stream: :sprint,
        status: :backlog,
        complexity: 3,
        due_on: Date.current
      )
      authorize agenda_item, :create?
      next unless agenda_item.save

      ActivityLogger.log_creation(agenda_item, current_user)
      created += 1
    end

    redirect_to project_path(@project), success: "Created #{created} agenda item(s) from Figma."
  end

  def mark_design_payment_received
    authorize @project, :update?

    @project.update!(design_payment_received_at: Time.current)
    redirect_to project_path(@project), success: "Design payment recorded. You can run designer agent #1 when ready."
  end

  def run_designer_agent_wireframe
    authorize @project, :update?

    sprint = @project.sprints.find_by(id: params[:sprint_id])
    unless sprint
      redirect_to project_path(@project), alert: "Choose a sprint for generated tasks."
      return
    end

    result = Agents::WireframeDesignerTaskPlanner.call(project: @project, sprint: sprint, acting_user: current_user)
    redirect_to project_path(@project), success: "Designer agent created #{result[:created_count]} agenda item(s)."
  rescue Agents::WireframeDesignerTaskPlanner::Error, Agents::OpenAiChat::Error => e
    redirect_to project_path(@project), alert: e.message
  end

  def run_developer_agent_from_spec
    authorize @project, :update?

    sprint = @project.sprints.find_by(id: params[:sprint_id])
    unless sprint
      redirect_to project_path(@project), alert: "Choose a sprint for generated tasks."
      return
    end

    skip_pay = ActiveModel::Type::Boolean.new.cast(params[:skip_sprint_payment])
    result = Agents::MarkdownDeveloperTaskPlanner.call(
      project: @project,
      sprint: sprint,
      acting_user: current_user,
      require_sprint_payment: !skip_pay
    )
    redirect_to project_path(@project), success: "Developer agent created #{result[:created_count]} agenda item(s)."
  rescue Agents::MarkdownDeveloperTaskPlanner::Error, Agents::OpenAiChat::Error => e
    redirect_to project_path(@project), alert: e.message
  end

  def run_designer_agent_figma_sync
    authorize @project, :update?

    result = Agents::FigmaAgendaSync.call(project: @project, user: current_user)
    redirect_to project_path(@project), success: "Figma sync updated #{result[:updated_count]} agenda item(s)."
  rescue Agents::FigmaAgendaSync::Error, Figma::FileFetcher::MissingToken, Figma::FileFetcher::Unauthorized,
         Figma::FileFetcher::NotFound, Figma::FileFetcher::Error => e
    redirect_to project_path(@project), alert: e.message
  end

  def generate_documentation_agent
    authorize @project, :update?

    meta = Agents::DocumentationGenerator.call(project: @project)
    redirect_to project_documentation_page_path(@project, meta[:slug]), success: "Documentation refreshed."
  rescue Agents::DocumentationGenerator::Error, Agents::OpenAiChat::Error => e
    redirect_to project_path(@project), alert: e.message
  end

  private

  def set_project
    @project = policy_scope(Project).includes(:client).find(params[:id])
  end

  def set_form_collections
    @clients = policy_scope(Client).ordered
  end

  def project_params
    params.require(:project).permit(
      :client_id, :name, :description, :estimated_cost, :start_date, :end_date,
      :design_brief, :design_prompt, :generated_design_url, :figma_file_key,
      :wireframe_outline, :dev_task_spec_markdown,
      wireframe_files: []
    )
  end

  def load_figma_import_collections
    @sprints = @project.sprints.order(start_date: :desc, created_at: :desc)
    @assignees = User.active.order(:first_name, :last_name) if current_user&.internal_role?
    @assignees ||= []
  end

  def extract_figma_file_key(input)
    return nil if input.blank?
    s = input.to_s.strip
    # design/file/proto: standard files; make: Figma Make (https://www.figma.com/make/{key}/...)
    m = s.match(%r{figma\.com/(?:file|design|proto|make)/([a-zA-Z0-9]+)})
    return m[1] if m

    s if s.match?(/\A[a-zA-Z0-9_-]+\z/)
  end

  def normalize_figma_task_rows(raw_tasks)
    hash =
      case raw_tasks
      when ActionController::Parameters
        raw_tasks.to_unsafe_h
      when Hash
        raw_tasks
      else
        {}
      end

    hash.sort_by { |k, _| k.to_s.to_i }.map do |_, v|
      case v
      when ActionController::Parameters
        v.to_unsafe_h.stringify_keys
      when Hash
        v.stringify_keys
      else
        {}
      end
    end
  end

  def project_filter_params
    permitted = params.fetch(:filters, {}).permit(:client_id, :search)
    {
      client_id: permitted[:client_id].presence&.to_i,
      search: permitted[:search].presence
    }
  end

  def clients_for_filter
    if current_user&.client? && current_user.client.present?
      [current_user.client]
    else
      policy_scope(Client).ordered
    end
  end

  def build_project_stats(items)
    items = items.to_a
    total = items.size
    completed = items.select(&:completed?).size
    in_progress = items.select(&:in_progress?).size
    blocked = items.select(&:blocked?).size
    overdue = items.select(&:due_on).select { |item| item.due_on < Date.current && !item.completed? }.size

    {
      total: total,
      completed: completed,
      in_progress: in_progress,
      blocked: blocked,
      overdue: overdue,
      progress: percentage(completed, total)
    }
  end

  def build_sprint_summaries(sprints)
    sprints.map do |sprint|
      items = sprint.agenda_items.to_a
      total = items.size
      completed = items.select(&:completed?).size
      in_progress = items.select(&:in_progress?).size

      {
        sprint: sprint,
        total: total,
        completed: completed,
        in_progress: in_progress,
        blocked: items.select(&:blocked?).size,
        progress: percentage(completed, total)
      }
    end
  end

  def percentage(part, total)
    return 0 if total.to_i.zero?

    ((part.to_f / total) * 100).round
  end
end
