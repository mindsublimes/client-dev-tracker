# frozen_string_literal: true

class FigmaOauthController < ApplicationController
  before_action :authenticate_user!
  before_action :require_internal_user!

  def connect
    unless Figma::Oauth.configured?
      redirect_back fallback_location: root_path,
                    alert: "Figma OAuth is not configured. Set FIGMA_CLIENT_ID, FIGMA_CLIENT_SECRET, and FIGMA_OAUTH_REDIRECT_URI."
      return
    end

    return_to = params[:return_to].to_s
    session[:figma_oauth_return_to] = return_to if return_to.start_with?("/") && !return_to.start_with?("//")

    state = SecureRandom.hex(24)
    session[:figma_oauth_state] = state
    redirect_to Figma::Oauth.authorization_url(state: state), allow_other_host: true
  end

  def callback
    if params[:error].present?
      redirect_to after_oauth_path, alert: (params[:error_description].presence || "Figma authorization was cancelled.")
      return
    end

    if session[:figma_oauth_state].blank? || params[:state].to_s != session[:figma_oauth_state].to_s
      redirect_to after_oauth_path, alert: "Invalid OAuth state. Please try connecting again."
      return
    end

    session.delete(:figma_oauth_state)

    code = params[:code].to_s
    if code.blank?
      redirect_to after_oauth_path, alert: "Missing authorization code from Figma."
      return
    end

    data = Figma::Oauth.exchange_code(code: code)
    current_user.apply_figma_oauth_response!(data)
    redirect_to after_oauth_path, success: "Figma account connected. You can import tasks from files you can access."
  rescue Figma::Oauth::Error => e
    redirect_to after_oauth_path, alert: e.message
  end

  def disconnect
    current_user.disconnect_figma!
    redirect_back fallback_location: root_path, notice: "Figma disconnected from your account."
  end

  private

  def require_internal_user!
    return if current_user&.internal_role?

    redirect_to root_path, alert: "You are not authorized to connect Figma."
  end

  def after_oauth_path
    session.delete(:figma_oauth_return_to).presence || projects_path
  end
end
