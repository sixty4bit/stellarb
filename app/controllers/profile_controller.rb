# frozen_string_literal: true

class ProfileController < ApplicationController
  # GET /profile
  # Shows the user's profile with their current settings
  def show
    @user = current_user
  end

  # GET /profile/edit
  # Renders the profile edit form
  def edit
    @user = current_user
  end

  # PATCH /profile
  # Updates the user's profile information
  def update
    @user = current_user

    if @user.update(profile_params)
      @user.complete_profile!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to profile_path, notice: "Profile updated successfully." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :sound_enabled)
  end
end
