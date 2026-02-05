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

    # Complete the emigration (teleports ships, records visit, updates user)
    current_user.emigrate_to!(hub)

    redirect_to root_path, notice: "Welcome to #{hub.system.name}! Your journey as a colonist begins now."
  rescue User::InvalidHubError
    flash.now[:alert] = "Invalid hub selection. The hub is no longer certified."
    @dossiers = PlayerHub.emigration_dossiers
    render :show, status: :unprocessable_entity
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
