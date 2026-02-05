class SessionsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    @user = User.new
  end

  def create
    email = params[:user][:email].downcase.strip

    # For development, auto-login with any email
    # In production, this would send a magic link
    user = User.find_or_create_by(email: email) do |u|
      u.name = email.split('@').first.capitalize
    end

    if user.persisted?
      user.update(
        last_sign_in_at: Time.current,
        sign_in_count: user.sign_in_count + 1
      )
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Something went wrong. Please try again."
      render :new
    end
  end

  def check_email
    # This would show "Check your email" page in production
    # For now, just redirect to login
    redirect_to new_session_path
  end

  def destroy
    session[:user_id] = nil
    redirect_to new_session_path, notice: "Signed out successfully."
  end
end
