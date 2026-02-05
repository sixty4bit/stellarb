class MarketController < ApplicationController
  before_action :set_system
  before_action :set_active_menu

  def index
    # Verify user has visited this system
    unless current_user.visited_systems.include?(@system)
      redirect_to systems_path, alert: "You must visit a system before viewing its market."
      return
    end

    # Generate market data (prices are procedural based on system seed)
    @market_data = generate_market_data

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Systems", path: systems_path },
      { name: @system.name, path: system_path(@system) },
      { name: "Market" }
    ]
  end

  def buy
    # TODO: Implement buy logic
    redirect_to system_market_index_path(@system), notice: "Purchase complete!"
  end

  def sell
    # TODO: Implement sell logic
    redirect_to system_market_index_path(@system), notice: "Sale complete!"
  end

  private

  def set_system
    @system = System.find(params[:system_id])
  end

  def set_active_menu(_unused = nil)
    @active_menu = :systems
  end

  def generate_market_data
    # Placeholder market data - would use procedural generation in production
    [
      { commodity: "ore", buy_price: 50, sell_price: 45, inventory: 1000, trend: :up },
      { commodity: "water", buy_price: 30, sell_price: 27, inventory: 500, trend: :stable },
      { commodity: "fuel", buy_price: 100, sell_price: 90, inventory: 250, trend: :down },
      { commodity: "food", buy_price: 25, sell_price: 22, inventory: 800, trend: :stable },
      { commodity: "electronics", buy_price: 200, sell_price: 180, inventory: 100, trend: :up },
      { commodity: "medicine", buy_price: 150, sell_price: 135, inventory: 50, trend: :up }
    ]
  end
end
