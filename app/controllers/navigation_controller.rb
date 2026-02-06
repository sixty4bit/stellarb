class NavigationController < ApplicationController
  before_action :set_active_menu
  before_action :check_ship_arrivals
  before_action :set_ship

  def index
    # Get the user's current location
    @current_system = @ship&.current_system || cradle_system

    # Get warp-connected systems (instant travel via gates)
    @warp_destinations = build_warp_destinations

    # Get nearby systems within conventional travel range
    @nearby_systems = build_nearby_systems

    # Pre-select destination if passed from system show page
    @requested_destination = System.find_by(id: params[:destination_id])

    # Set breadcrumbs
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Navigation" }
    ]
  end

  def warp
    destination = System.find_by(id: params[:destination_id])

    unless destination
      flash[:alert] = "Destination system not found"
      return redirect_to navigation_index_path
    end

    unless @ship
      flash[:alert] = "No ship available for travel"
      return redirect_to navigation_index_path
    end

    # Determine travel type and execute
    intent = params[:intent] || "trade"
    result = execute_travel(destination, intent)

    if result.success?
      flash[:notice] = "Warp successful! Arrived at #{destination.name}"
    else
      flash[:alert] = result.error
    end

    redirect_to navigation_index_path
  end

  private

  def check_ship_arrivals
    current_user.ships.in_transit.find_each(&:check_arrival!)
  end

  def set_active_menu
    super(:navigation)
  end

  def set_ship
    @ship = current_user.ships.operational.first
  end

  def cradle_system
    System.find_by(x: 0, y: 0, z: 0) ||
      System.discover_at(x: 0, y: 0, z: 0, user: current_user)
  end

  def build_warp_destinations
    return [] unless @ship&.current_system

    @ship.current_system.warp_connected_systems.map do |system|
      fuel_cost = @ship.warp_fuel_required_for(system)
      {
        system: system,
        distance: @ship.current_system.distance_to(system).round(1),
        fuel_cost: fuel_cost.round(1),
        can_reach: @ship.can_warp_to?(system),
        travel_type: :warp
      }
    end
  end

  def build_nearby_systems
    return [] unless @ship&.current_system

    # Get all known systems within potential reach (fuel * 2 for visibility)
    max_range = @ship.fuel * 2
    current = @ship.current_system

    System.where.not(id: current.id).select do |system|
      current.distance_to(system) <= max_range
    end.map do |system|
      distance = current.distance_to(system).round(1)
      fuel_cost = @ship.fuel_required_for(system).round(1)
      travel_time = @ship.travel_time_to(system)

      {
        system: system,
        distance: distance,
        fuel_cost: fuel_cost,
        travel_time: format_travel_time(travel_time),
        can_reach: @ship.can_reach?(system),
        travel_type: :conventional
      }
    end.sort_by { |s| s[:distance] }
  end

  def execute_travel(destination, intent)
    # Prefer warp if available (instant)
    if @ship.current_system.warp_connected_to?(destination)
      @ship.warp_to!(destination, intent: intent)
    else
      @ship.travel_to!(destination, intent: intent)
    end
  end

  def format_travel_time(seconds)
    return "instant" if seconds.zero?

    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{(seconds / 60.0).ceil}m"
    else
      "#{(seconds / 3600.0).round(1)}h"
    end
  end
end
