class AboutController < ApplicationController
  before_action :set_active_menu

  def index
    @stats = {
      ships: current_user.ships.count,
      buildings: current_user.buildings.count,
      systems_discovered: current_user.discovered_systems.count,
      workers: current_user.hired_recruits.count,
      playtime: "#{((Time.current - current_user.created_at) / 1.day).round} days"
    }
  end

  private

  def set_active_menu
    super(:about)
  end
end
