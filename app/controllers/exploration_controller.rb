class ExplorationController < ApplicationController
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

    # Check if ship just arrived and needs realization
    if @ship&.status == "docked" && @ship.current_system_id.nil? && @ship.location_x.present?
      @service.realize_and_arrive!(@ship)
      @ship.reload
    end
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

    if ship.status == "in_transit"
      redirect_to exploration_path, alert: "Ship is already in transit"
      return
    end

    service = ExplorationService.new(current_user, ship)
    direction = DIRECTION_MAP[direction_key]
    target = service.closest_unexplored(direction: direction)

    unless target
      redirect_to exploration_path, alert: "No unexplored coordinates in that direction"
      return
    end

    # Initiate travel to target coordinates
    result = ship.travel_to_coordinates!(target[:x], target[:y], target[:z], intent: :explore)

    if result.success?
      redirect_to exploration_path, notice: "Ship traveling to (#{target[:x]}, #{target[:y]}, #{target[:z]})..."
    else
      redirect_to exploration_path, alert: result.error
    end
  end

  def growing_arcs
    ship = current_user.ships.operational.first
    return redirect_to(exploration_path, alert: "No operational ship") unless ship
    return redirect_to(exploration_path, alert: "Ship is in transit") if ship.status == "in_transit"

    service = ExplorationService.new(current_user, ship)
    target = service.closest_unexplored

    unless target
      redirect_to exploration_path, alert: "All coordinates explored!"
      return
    end

    result = ship.travel_to_coordinates!(target[:x], target[:y], target[:z], intent: :explore)
    if result.success?
      redirect_to exploration_path, notice: "Ship traveling to (#{target[:x]}, #{target[:y]}, #{target[:z]})..."
    else
      redirect_to exploration_path, alert: result.error
    end
  end

  def orbit
    ship = current_user.ships.operational.first
    return redirect_to(exploration_path, alert: "No operational ship") unless ship
    return redirect_to(exploration_path, alert: "Ship is in transit") if ship.status == "in_transit"

    service = ExplorationService.new(current_user, ship)
    target = service.closest_unexplored_orbital

    unless target
      redirect_to exploration_path, alert: "All orbital coordinates explored!"
      return
    end

    result = ship.travel_to_coordinates!(target[:x], target[:y], target[:z], intent: :explore)
    if result.success?
      redirect_to exploration_path, notice: "Ship traveling to (#{target[:x]}, #{target[:y]}, #{target[:z]})..."
    else
      redirect_to exploration_path, alert: result.error
    end
  end
end
