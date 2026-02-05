class NavigationController < ApplicationController
  before_action :set_active_menu

  def index
    # Get the user's current location
    system = current_user.ships.first&.current_system
    @current_system = system ? system_to_hash(system) : generate_cradle_system

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

  # Convert a System model to hash format for the view
  def system_to_hash(system)
    {
      name: system.name,
      coordinates: { x: system.x, y: system.y, z: system.z },
      star_type: system.properties&.dig("star_type") || "unknown",
      planet_count: system.properties&.dig("planet_count") || 0,
      hazard_level: system.properties&.dig("hazard_level") || 0
    }
  end
end