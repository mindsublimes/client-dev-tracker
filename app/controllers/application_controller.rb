class ApplicationController < ActionController::Base
  include Pundit::Authorization

  add_flash_types :success, :warning

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :switch_time_zone, if: :current_user

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def after_sign_in_path_for(_resource)
    dashboard_path
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name time_zone])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name time_zone])
  end

  def switch_time_zone(&block)
    Time.use_zone(current_user.time_zone, &block)
  end

  def user_not_authorized
    redirect_back(fallback_location: dashboard_path, alert: 'You are not authorized to perform this action.')
  end
end
