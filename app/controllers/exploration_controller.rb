class ExplorationController < ApplicationController
  # Direction mapping from UI (+x/-x) to service (spinward/antispinward)
  DIRECTION_MAP = {
    "+x" => :spinward,
    "-x" => :antispinward,
    "+y" => :north,
    "-y" => :south,
    "+z" => :up,
    "-z" => :down
  }.freeze

  def show
    @ship = current_user.ships.operational.first
    @service = ExplorationService.new(current_user, @ship) if @ship
    @current_position = @service&.current_position
    @explored_count = current_user.system_visits.count
  end

  def single_direction
    direction_key = params[:direction]

    unless DIRECTION_MAP.key?(direction_key)
      redirect_to exploration_path, alert: "Invalid direction: #{direction_key}"
      return
    end

    ship = current_user.ships.operational.first

    unless ship
      redirect_to exploration_path, alert: "No operational ship available"
      return
    end

    service = ExplorationService.new(current_user, ship)
    direction = DIRECTION_MAP[direction_key]
    target = service.closest_unexplored(direction: direction)

    if target
      # Mark as explored using ExploredCoordinate
      has_system = System.exists?(x: target[:x], y: target[:y], z: target[:z])
      ExploredCoordinate.mark_explored!(
        user: current_user,
        x: target[:x],
        y: target[:y],
        z: target[:z],
        has_system: has_system
      )

      if has_system
        redirect_to exploration_path, notice: "Discovered system at #{target[:x]},#{target[:y]},#{target[:z]}! Navigate there to explore further."
      else
        redirect_to exploration_path, notice: "Explored empty space at #{target[:x]},#{target[:y]},#{target[:z]}"
      end
    else
      redirect_to exploration_path, alert: "No unexplored coordinates in that direction"
    end
  end

  def growing_arcs
    # Placeholder - to be implemented in 2bj.4
    redirect_to exploration_path, notice: "Growing arcs exploration coming soon!"
  end

  def orbit
    # Placeholder - to be implemented in 2bj.5
    redirect_to exploration_path, notice: "Orbit exploration coming soon!"
  end

  private

  def current_position
    return nil unless @ship

    if @ship.current_system
      {
        x: @ship.current_system.x,
        y: @ship.current_system.y,
        z: @ship.current_system.z
      }
    elsif @ship.location_x && @ship.location_y && @ship.location_z
      {
        x: @ship.location_x,
        y: @ship.location_y,
        z: @ship.location_z
      }
    end
  end
end
