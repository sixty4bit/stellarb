# frozen_string_literal: true

class RecruitersController < ApplicationController
  before_action :set_active_menu
  before_action :set_recruit, only: [:show, :hire]

  # Task stellarb-b2a: List available recruits
  def index
    @recruits = Recruit.available_for(current_user).order(skill: :desc)
    @next_refresh = @recruits.minimum(:expires_at) if @recruits.any?

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Recruiter" }
    ]
  end

  # Task stellarb-04o: Show recruit details
  def show
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Recruiter", path: recruiters_path },
      { name: @recruit.display_name }
    ]
  end

  # Task stellarb-r9a: Hire a recruit
  def hire
    # Find assignable (required - DB constraint)
    assignable = find_assignable
    if assignable.nil?
      redirect_to recruiters_path, alert: "Recruit must be assigned to a ship or building."
      return
    end

    # Calculate hire cost (2 weeks advance)
    hire_cost = @recruit.base_wage * 2

    # Check if user can afford it
    if current_user.credits < hire_cost
      redirect_to recruiters_path, alert: "Insufficient credits to hire this worker."
      return
    end

    begin
      # Use the Recruit#hire! method which handles:
      # - Creating HiredRecruit copy
      # - Creating Hiring record
      # - Expiring recruit from pool
      hiring = @recruit.hire!(current_user, assignable)

      # Deduct credits
      current_user.decrement!(:credits, hire_cost)

      redirect_to worker_path(hiring.hired_recruit), notice: "Successfully hired #{hiring.hired_recruit.name}!"
    rescue Recruit::AlreadyHiredError, Recruit::NotAvailableError
      redirect_to recruiters_path, alert: "This recruit is no longer available."
    end
  end

  private

  def set_active_menu(_unused = nil)
    @active_menu = :workers
  end

  def set_recruit
    @recruit = Recruit.find(params[:id])
  end

  # Find the assignable (Ship or Building) if specified in params
  def find_assignable
    return nil unless params[:assignable_type].present? && params[:assignable_id].present?

    case params[:assignable_type]
    when "Ship"
      current_user.ships.find_by(id: params[:assignable_id])
    when "Building"
      current_user.buildings.find_by(id: params[:assignable_id])
    end
  end
end
