class ExplorationController < ApplicationController
  def show
    # Using system_visits until explored_coordinates is added in 2bj.6
    @explored_count = current_user.system_visits.count
  end

  def single_direction
    # Placeholder - to be implemented in 2bj.3
    redirect_to exploration_path, notice: "Single direction exploration coming soon!"
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

  # Explore coordinates in an orbital pattern around current position
  # Prioritizes same distance from origin, then expands outward
  def orbit
    ship = current_user.ships.operational.first
    service = ExplorationService.new(current_user, ship)

    target = service.closest_unexplored_orbital

    if target
      ExploredCoordinate.mark_explored!(
        user: current_user,
        x: target[:x],
        y: target[:y],
        z: target[:z],
        has_system: System.exists?(x: target[:x], y: target[:y], z: target[:z])
      )

      redirect_to exploration_path, notice: "Explored #{target[:x]},#{target[:y]},#{target[:z]}"
    else
      redirect_to exploration_path, alert: "All orbital coordinates explored!"
    end
  end
end
