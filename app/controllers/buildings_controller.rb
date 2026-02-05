class BuildingsController < ApplicationController
  before_action :set_active_menu
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
      system = System.find(params[:system_id])
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
    @current_system = System.find(params[:system_id]) if params[:system_id]
    # TODO: Generate available building types based on system
  end

  def create
    @building = current_user.buildings.build(building_params)
    if @building.save
      redirect_to @building, notice: "Building construction started!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def repair
    # TODO: Implement repair logic
    redirect_to @building, notice: "Building repaired!"
  end

  def upgrade
    # TODO: Implement upgrade logic
    redirect_to @building, notice: "Building upgrade started!"
  end

  def demolish
    @building.destroy
    redirect_to buildings_path, notice: "Building demolished."
  end

  private

  def set_active_menu
    super(:buildings)
  end

  def set_building
    @building = current_user.buildings.find(params[:id])
  end

  def building_params
    params.require(:building).permit(:name, :system_id, :race, :function, :tier)
  end
end