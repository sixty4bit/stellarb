class NavigationController < ApplicationController
  before_action :set_active_menu

  def index
    # Get the user's current location
    @current_system = current_user.ships.first&.current_system || generate_cradle_system

    # Get nearby systems within fuel range
    @nearby_systems = [] # TODO: Calculate based on ship fuel range

    # Get active routes
    @active_routes = [] # TODO: Load from user's routes

    # Set breadcrumbs
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Navigation" }
    ]
  end

  private

  def set_active_menu
    super(:navigation)
  end

  def generate_cradle_system
    # Generate The Cradle system for new players
    ProceduralGeneration.generate_system(0, 0, 0)
  end
end