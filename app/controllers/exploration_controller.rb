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
    ship = current_user.ships.operational.first
    service = ExplorationService.new(current_user, ship)

    target = service.closest_unexplored

    if target
      ExploredCoordinate.mark_explored!(
        user: current_user,
        x: target[:x], y: target[:y], z: target[:z],
        has_system: System.exists?(x: target[:x], y: target[:y], z: target[:z])
      )

      redirect_to exploration_path, notice: "Explored #{target[:x]},#{target[:y]},#{target[:z]}"
    else
      redirect_to exploration_path, alert: "All coordinates explored!"
    end
  end

  def orbit
    ship = current_user.ships.operational.first
    service = ExplorationService.new(current_user, ship)

    target = service.closest_unexplored_orbital

    if target
      ExploredCoordinate.mark_explored!(
        user: current_user,
        x: target[:x], y: target[:y], z: target[:z],
        has_system: System.exists?(x: target[:x], y: target[:y], z: target[:z])
      )

      redirect_to exploration_path, notice: "Explored #{target[:x]},#{target[:y]},#{target[:z]}"
    else
      redirect_to exploration_path, alert: "All orbital coordinates explored!"
    end
  end
end
