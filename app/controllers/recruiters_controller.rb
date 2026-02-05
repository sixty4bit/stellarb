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
    # Implementation in task stellarb-r9a
    redirect_to recruiters_path
  end

  private

  def set_active_menu(_unused = nil)
    @active_menu = :workers
  end

  def set_recruit
    @recruit = Recruit.find(params[:id])
  end
end
