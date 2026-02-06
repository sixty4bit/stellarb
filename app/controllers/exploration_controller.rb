class ExplorationController < ApplicationController
  def show
  end

  def growing_arcs
    ship = current_user.ships.operational.first
    service = ExplorationService.new(current_user, ship)

    target = service.closest_unexplored

    if target
      current_user.explored_coordinates.create!(
        x: target[:x], y: target[:y], z: target[:z],
        has_system: System.exists?(x: target[:x], y: target[:y], z: target[:z])
      )

      redirect_to exploration_path, notice: "Explored #{target[:x]},#{target[:y]},#{target[:z]}"
    else
      redirect_to exploration_path, alert: "All coordinates explored!"
    end
  end
end
