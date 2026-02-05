class WorkersController < ApplicationController
  before_action :set_active_menu
  before_action :set_worker, only: [:show, :fire, :assign]

  def index
    @workers = current_user.hired_recruits.includes(:hirings)
    @unassigned_workers = @workers.joins(:hirings).where(hirings: { assignable_id: nil })

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Workers" }
    ]
  end

  def show
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Workers", path: workers_path },
      { name: @worker.name }
    ]
  end

  def recruiter
    # Get available recruits for user's level tier
    @available_recruits = Recruit.available_for(current_user)
    @next_refresh = @available_recruits.minimum(:expires_at) if @available_recruits.any?

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Workers", path: workers_path },
      { name: "Recruiter" }
    ]
  end

  def hire
    recruit = Recruit.find(params[:recruit_id])

    # Check if recruit is still available
    if recruit.available_for?(current_user)
      # Create hired recruit copy
      hired_recruit = HiredRecruit.create!(
        original_recruit: recruit,
        race: recruit.race,
        npc_class: recruit.npc_class,
        skill: recruit.skill,
        stats: recruit.base_stats,
        employment_history: recruit.employment_history,
        chaos_factor: recruit.chaos_factor
      )

      # Create hiring record
      hiring = current_user.hirings.create!(
        hired_recruit: hired_recruit,
        hired_at: Time.current,
        wage: recruit.base_wage,
        status: :active
      )

      # Deduct cost from user
      hire_cost = recruit.base_wage * 2 # Two weeks advance
      if current_user.credits >= hire_cost
        current_user.decrement!(:credits, hire_cost)
        redirect_to worker_path(hired_recruit), notice: "Successfully hired #{hired_recruit.name}!"
      else
        hiring.destroy
        hired_recruit.destroy
        redirect_to recruiter_workers_path, alert: "Insufficient credits to hire this worker."
      end
    else
      redirect_to recruiter_workers_path, alert: "This recruit is no longer available."
    end
  end

  def fire
    hiring = @worker.hirings.find_by(user: current_user)
    if hiring
      hiring.update!(status: :fired, terminated_at: Time.current)
      redirect_to workers_path, notice: "#{@worker.name} has been fired."
    else
      redirect_to workers_path, alert: "Worker not found."
    end
  end

  def assign
    # TODO: Implement worker assignment to ships/buildings
    redirect_to @worker
  end

  private

  def set_active_menu(_unused = nil)
    @active_menu = :workers
  end

  def set_worker
    @worker = HiredRecruit.find(params[:id])
    # TODO: Verify user owns this worker
  end
end