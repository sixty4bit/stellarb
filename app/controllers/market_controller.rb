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
    ship = current_user.ships.find(params[:ship_id])
    commodity = params[:commodity]
    quantity = params[:quantity].to_i
    
    # Get price for this commodity
    market_item = generate_market_data.find { |m| m[:commodity] == commodity }
    unless market_item
      redirect_to system_market_index_path(@system), alert: "Unknown commodity: #{commodity}"
      return
    end
    
    price = market_item[:buy_price]
    total_cost = price * quantity
    
    # Check credits
    if current_user.credits < total_cost
      redirect_to system_market_index_path(@system), alert: "Insufficient credits (need #{total_cost}, have #{current_user.credits.to_i})"
      return
    end
    
    # Check cargo space
    if ship.available_cargo_space < quantity
      redirect_to system_market_index_path(@system), alert: "Insufficient cargo space (need #{quantity}, have #{ship.available_cargo_space})"
      return
    end
    
    # Execute purchase
    ActiveRecord::Base.transaction do
      current_user.update!(credits: current_user.credits - total_cost)
      ship.add_cargo!(commodity, quantity)
    end
    
    redirect_to system_market_index_path(@system), notice: "Purchased #{quantity} #{commodity} for #{total_cost} credits"
  end

  def sell
    ship = current_user.ships.find(params[:ship_id])
    commodity = params[:commodity]
    quantity = params[:quantity].to_i
    
    # Get price for this commodity
    market_item = generate_market_data.find { |m| m[:commodity] == commodity }
    unless market_item
      redirect_to system_market_index_path(@system), alert: "Unknown commodity: #{commodity}"
      return
    end
    
    # Check if we have this commodity
    cargo_qty = ship.cargo_quantity_for(commodity)
    if cargo_qty == 0
      redirect_to system_market_index_path(@system), alert: "You don't have any #{commodity} to sell"
      return
    end
    
    # Check if we have enough
    if cargo_qty < quantity
      redirect_to system_market_index_path(@system), alert: "Insufficient #{commodity} in cargo (have #{cargo_qty}, need #{quantity})"
      return
    end
    
    price = market_item[:sell_price]
    total_income = price * quantity
    
    # Execute sale
    ActiveRecord::Base.transaction do
      current_user.update!(credits: current_user.credits + total_income)
      ship.remove_cargo!(commodity, quantity)
    end
    
    redirect_to system_market_index_path(@system), notice: "Sold #{quantity} #{commodity} for #{total_income} credits"
  end

  private

  def set_system
    @system = System.find(params[:system_id])
  end

  def set_active_menu(_unused = nil)
    @active_menu = :systems
  end

  def generate_market_data
    # Get current prices (base prices + deltas) from the system
    current_prices = @system.current_prices
    
    current_prices.map do |commodity, base_price|
      {
        commodity: commodity.to_s,
        buy_price: calculate_buy_price(base_price),
        sell_price: calculate_sell_price(base_price),
        inventory: calculate_inventory(commodity),
        trend: calculate_trend(commodity)
      }
    end
  end
  
  # Buy price is 10% higher than base (player pays more)
  def calculate_buy_price(base_price)
    (base_price * 1.10).round
  end
  
  # Sell price is 10% lower than base (player receives less)
  def calculate_sell_price(base_price)
    (base_price * 0.90).round
  end
  
  # Inventory is procedurally generated (placeholder for now)
  def calculate_inventory(commodity)
    # Use system seed to generate consistent inventory levels
    seed = Digest::SHA256.hexdigest("#{@system.id}|#{commodity}|inventory")
    100 + (seed[0, 4].to_i(16) % 900) # 100-1000 units
  end
  
  # Trend is based on recent price deltas (placeholder for now)
  def calculate_trend(commodity)
    delta = PriceDelta.find_by(system: @system, commodity: commodity.to_s)
    return :stable unless delta
    
    case delta.delta_cents
    when 1.. then :up
    when ..-1 then :down
    else :stable
    end
  end
end
