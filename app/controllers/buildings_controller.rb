class BuildingsController < ApplicationController
  before_action :set_active_menu
  before_action :check_construction_completions
  before_action :set_building, only: [:show, :repair, :upgrade, :demolish]

  def index
    @buildings = current_user.buildings.includes(:system, :staff)

    # Handle filters
    if params[:type].present?
      @buildings = @buildings.where(function: params[:type])
    end

    if params[:system_id].present?
      @buildings = @buildings.where(system_id: params[:system_id])
    end

    @breadcrumbs = if params[:system_id]
      system = System.find_by!(short_id: params[:system_id]) rescue System.find(params[:system_id])
      [
        { name: current_user.name, path: root_path },
        { name: "Systems", path: systems_path },
        { name: system.name, path: system_path(system) },
        { name: "Buildings" }
      ]
    else
      [
        { name: current_user.name, path: root_path },
        { name: "Buildings" }
      ]
    end
  end

  def show
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Buildings", path: buildings_path },
      { name: @building.name }
    ]
  end

  def new
    @building = current_user.buildings.build
    @current_system = System.find_by(id: params[:system_id])
    @constructable_types = Building.constructable_types
    @user_credits = current_user.credits

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Buildings", path: buildings_path },
      { name: "New Building" }
    ]
  end

  def create
    @building = current_user.buildings.build(building_params)

    # Set status to under_construction for new buildings
    @building.status = "under_construction"

    # Validate params before cost check to avoid ArgumentError
    unless Building::FUNCTIONS.include?(@building.function)
      @building.errors.add(:function, "is not a valid function")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    unless Building::RACES.include?(@building.race)
      @building.errors.add(:race, "is not a valid race")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    unless @building.tier.present? && (1..5).include?(@building.tier.to_i)
      @building.errors.add(:tier, "must be between 1 and 5")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    # Validate affordability before attempting save
    unless current_user.can_afford_building?(function: @building.function, tier: @building.tier, race: @building.race)
      @building.errors.add(:base, "Insufficient credits to construct this building")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      # Deduct cost from user
      current_user.deduct_building_cost!(function: @building.function, tier: @building.tier, race: @building.race)

      if @building.save
        redirect_to @building, notice: "Building construction started!"
      else
        # Rollback will restore credits
        raise ActiveRecord::Rollback
      end
    end

    # If we get here without redirecting, save failed
    unless performed?
      setup_new_view_vars
      render :new, status: :unprocessable_entity
    end
  end

  def repair
    # TODO: Implement repair logic
    redirect_to @building, notice: "Building repaired!"
  end

  def upgrade
    unless @building.upgradeable?
      redirect_to @building, alert: "Building cannot be upgraded (max tier or not operational)."
      return
    end

    begin
      @building.upgrade!(user: current_user)
      redirect_to @building, notice: "Building upgraded to Tier #{@building.tier}!"
    rescue User::InsufficientCreditsError => e
      redirect_to @building, alert: "Upgrade failed: #{e.message}"
    rescue Building::UpgradeError => e
      redirect_to @building, alert: "Upgrade failed: #{e.message}"
    end
  end

  def demolish
    @building.destroy
    redirect_to buildings_path, notice: "Building demolished."
  end

  private

  def check_construction_completions
    current_user.buildings.under_construction.find_each(&:check_construction_complete!)
  end

  def set_active_menu
    super(:buildings)
  end

  def set_building
    @building = current_user.buildings.find_by!(short_id: params[:id]) rescue current_user.buildings.find(params[:id])
  end

  def building_params
    params.require(:building).permit(:name, :system_id, :race, :function, :tier)
  end

  def setup_new_view_vars
    @current_system = System.find_by(id: params.dig(:building, :system_id))
    @constructable_types = Building.constructable_types
    @user_credits = current_user.credits
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Buildings", path: buildings_path },
      { name: "New Building" }
    ]
  end
end