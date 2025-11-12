class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update]

  def index
    @clients = policy_scope(Client).ordered.includes(:agenda_items)
  end

  def show
    authorize @client
    @agenda_items = @client.agenda_items.includes(:assignee).order(rank_score: :desc)
  end

  def new
    @client = Client.new
    authorize @client
  end

  def create
    @client = Client.new(client_params)
    authorize @client

    if @client.save
      redirect_to @client, success: 'Client created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @client
  end

  def update
    authorize @client

    if @client.update(client_params)
      redirect_to @client, success: 'Client updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_client
    @client = policy_scope(Client).find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :code, :contact_name, :contact_email, :priority_level, :status, :timezone, :notes)
  end
end
