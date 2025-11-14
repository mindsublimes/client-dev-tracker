module Admin
  class UsersController < ApplicationController
    before_action :set_user, only: %i[edit update]
    before_action :load_form_collections, only: %i[new create edit update]

    def index
      authorize User
      @users = policy_scope(User).includes(:client).order(:first_name, :last_name)
    end

    def new
      @user = User.new(time_zone: 'UTC', active: true)
      authorize @user
    end

    def create
      @user = User.new(user_params)
      authorize @user

      if @user.save
        redirect_to admin_users_path, success: 'User created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @user
    end

    def update
      authorize @user

      if @user.update(user_update_params)
        redirect_to admin_users_path, success: 'User updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = policy_scope(User).find_by(id: params[:id])
      return redirect_to admin_users_path, alert: 'User not found.' unless @user
    end

    def user_params
      permitted = %i[first_name last_name email role active time_zone client_id password password_confirmation]
      params.require(:user).permit(permitted).tap do |hash|
        hash[:client_id] = nil if hash[:client_id].blank?
      end
    end

    def user_update_params
      attributes = user_params
      if attributes[:password].blank?
        attributes.delete(:password)
        attributes.delete(:password_confirmation)
      end
      attributes
    end

    def load_form_collections
      @roles = User.roles.keys.map { |role| [role.titleize, role] }
      @clients = Client.order(:name)
    end
  end
end
