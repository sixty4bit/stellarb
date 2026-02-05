class SystemsController < ApplicationController
  before_action :set_active_menu
  before_action :set_system, only: [:show]

  def index
    # Show all systems the user has visited
    @systems = current_user.visited_systems.includes(:discovered_by)

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Systems" }
    ]
  end

  def show
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Systems", path: systems_path },
      { name: @system.name }
    ]

    # Get player assets in this system
    @ships_in_system = current_user.ships.where(current_system: @system)
    @buildings_in_system = current_user.buildings.where(system: @system)
  end

  private

  def set_active_menu
    super(:systems)
  end

  def set_system
    @system = System.find(params[:id])
    # TODO: Check if user has visited this system
  end
end