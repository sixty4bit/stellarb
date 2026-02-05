# frozen_string_literal: true

class EmigrationController < ApplicationController
  before_action :require_emigration_phase

  # GET /emigration
  # Shows the Phase 3 hub selection screen
  def show
    @dossiers = PlayerHub.emigration_dossiers
  end

  # POST /emigration
  # Processes hub selection and completes emigration
  def create
    hub = PlayerHub.find_emigration_hub_by_id(params[:hub_id])

    if hub.nil?
      flash.now[:alert] = "Invalid hub selection. Please choose from the available options."
      @dossiers = PlayerHub.emigration_dossiers
      render :show, status: :unprocessable_entity
      return
    end

    # Complete the emigration
    ActiveRecord::Base.transaction do
      # Update user status
      current_user.update!(
        tutorial_phase: :graduated,
        emigrated: true,
        emigrated_at: Time.current,
        emigration_hub_id: hub.id
      )

      # Track immigration at the hub
      hub.record_immigration!
    end

    redirect_to root_path, notice: "Welcome to #{hub.system.name}! Your journey as a colonist begins now."
  end

  private

  def require_emigration_phase
    if current_user.graduated? || current_user.emigrated?
      redirect_to root_path, alert: "You have already emigrated."
    elsif !current_user.emigration?
      redirect_to root_path, alert: "You are not ready for emigration yet. Complete the tutorial first."
    end
  end
end
