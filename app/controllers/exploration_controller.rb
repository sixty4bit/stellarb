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
    # Placeholder - to be implemented in 2bj.4
    redirect_to exploration_path, notice: "Growing arcs exploration coming soon!"
  end

  def orbit
    # Placeholder - to be implemented in 2bj.5
    redirect_to exploration_path, notice: "Orbit exploration coming soon!"
  end
end
