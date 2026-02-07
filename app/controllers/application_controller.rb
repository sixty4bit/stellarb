class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :require_profile_setup

  private

  def authenticate_user!
    redirect_to new_session_path unless current_user
  end

  def require_profile_setup
    return unless current_user
    return if current_user.profile_completed?
    return if controller_name == 'profile'    # Allow profile pages
    return if controller_name == 'sessions'   # Allow logout
    return if controller_name == 'onboarding' # Allow onboarding flow
    return if current_user.needs_onboarding?  # Don't interrupt tutorial with profile nag

    redirect_to edit_profile_path,
      notice: 'Welcome! Please set up your profile to continue.'
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  helper_method :current_user

  # Set the active menu item for navigation highlighting
  def set_active_menu(item)
    @active_menu = item
  end
end
