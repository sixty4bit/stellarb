class MarketController < ApplicationController
  before_action :set_system
  before_action :set_active_menu
  before_action :set_system_visit, only: [:index]
  before_action :require_marketplace, only: [:buy, :sell]

  def index
    # Check if trading is enabled for view purposes
    @trading_enabled = @system.trading_enabled?
    @marketplace = @system.marketplace
    # Verify user has visited this system
    unless current_user.visited_systems.include?(@system)
      redirect_to systems_path, alert: "You must visit a system before viewing its market."
      return
    end

    # Check if player has a ship docked at this system (real-time market access)
    @has_ship_docked = current_user.ships.exists?(current_system: @system, status: "docked")

    # Generate market data based on presence
    @market_data = generate_market_data
    
    # Set staleness info for the view
    if @has_ship_docked
      @price_source = :live
      @staleness_label = nil
    else
      @price_source = :snapshot
      @staleness_label = @system_visit&.staleness_label || "unknown"
    end

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Systems", path: systems_path },
      { name: @system.name, path: system_path(@system) },
      { name: "Market" }
    ]
  end

  def buy
    ship = find_trading_ship
    return unless ship

    # For trading, always use live prices (ship being docked is already validated)
    @has_ship_docked = true
    
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

    # Check inventory stock
    inventory = MarketInventory.for_system_commodity(@system, commodity)
    unless inventory&.available?(quantity)
      available = inventory&.quantity || 0
      redirect_to system_market_index_path(@system), alert: "Insufficient stock (only #{available} available)"
      return
    end

    # Calculate marketplace fee
    marketplace_fee = @system.marketplace.calculate_fee(total_cost)
    total_with_fee = total_cost + marketplace_fee

    # Check credits again with fee included
    if current_user.credits < total_with_fee
      redirect_to system_market_index_path(@system), alert: "Insufficient credits (need #{total_with_fee}, have #{current_user.credits.to_i})"
      return
    end

    # Execute purchase
    tax_paid = nil
    ActiveRecord::Base.transaction do
      current_user.update!(credits: current_user.credits - total_with_fee)
      ship.add_cargo!(commodity, quantity)
      inventory.decrease_stock!(quantity)
      
      # Pay tax to system owner (if any, and buyer isn't owner)
      base_price = @system.current_price(commodity)
      tax_paid = pay_owner_tax(base_price, quantity, :buy)
      
      # Simulate market demand - buying drives prices up
      PriceDelta.simulate_buy(@system, commodity, quantity)
    end

    notice = "Purchased #{quantity} #{commodity} for #{total_cost} credits"
    notice += " (#{marketplace_fee} cr marketplace fee)" if marketplace_fee > 0
    notice += " (#{tax_paid} cr tax to system owner)" if tax_paid
    redirect_to system_market_index_path(@system), notice: notice
  end

  def sell
    ship = find_trading_ship
    return unless ship

    # For trading, always use live prices (ship being docked is already validated)
    @has_ship_docked = true
    
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
    gross_income = price * quantity
    
    # Calculate marketplace fee (deducted from proceeds)
    marketplace_fee = @system.marketplace.calculate_fee(gross_income)
    net_income = gross_income - marketplace_fee

    # Execute sale
    tax_paid = nil
    ActiveRecord::Base.transaction do
      current_user.update!(credits: current_user.credits + net_income)
      ship.remove_cargo!(commodity, quantity)
      
      # Increase market inventory (capped at max)
      inventory = MarketInventory.for_system_commodity(@system, commodity)
      inventory&.increase_stock!(quantity)
      
      # Pay tax to system owner (if any, and seller isn't owner)
      base_price = @system.current_price(commodity)
      tax_paid = pay_owner_tax(base_price, quantity, :sell)
      
      # Simulate market supply - selling drives prices down
      PriceDelta.simulate_sell(@system, commodity, quantity)
    end

    notice = "Sold #{quantity} #{commodity} for #{net_income} credits"
    notice += " (#{marketplace_fee} cr marketplace fee)" if marketplace_fee > 0
    notice += " (#{tax_paid} cr tax to system owner)" if tax_paid
    redirect_to system_market_index_path(@system), notice: notice
  end

  private

  # Find the user's ship docked at this system for trading
  # Returns nil and redirects if no ship is available
  def find_trading_ship
    ship = current_user.ships.find_by(current_system: @system, status: "docked")
    unless ship
      redirect_to system_market_index_path(@system), alert: "You need a ship docked at this system to trade"
      return nil
    end
    ship
  end

  def set_system
    @system = System.find(params[:system_id])
  end

  def set_system_visit
    @system_visit = SystemVisit.find_by(user: current_user, system: @system)
  end

  def set_active_menu(_unused = nil)
    @active_menu = :systems
  end

  # Ensure a marketplace exists and is operational before trading
  def require_marketplace
    unless @system.trading_enabled?
      redirect_to system_market_index_path(@system), alert: "Trading disabled: no marketplace in this system"
      return false
    end
    true
  end

  def generate_market_data
    # Use live prices if player has ship docked, otherwise use snapshot
    prices = if @has_ship_docked
      @system.current_prices
    else
      @system_visit&.remembered_prices || {}
    end
    
    prices.map do |commodity, base_price|
      {
        commodity: commodity.to_s,
        buy_price: calculate_buy_price(base_price),
        sell_price: calculate_sell_price(base_price),
        inventory: calculate_inventory(commodity),
        trend: calculate_trend(commodity)
      }
    end
  end
  
  # Buy price - owners buy at base price, others pay 10% spread
  def calculate_buy_price(base_price)
    if @system.owned_by?(current_user)
      base_price.round
    else
      (base_price * 1.10).round
    end
  end
  
  # Sell price - owners sell at base price, others get 10% less
  def calculate_sell_price(base_price)
    if @system.owned_by?(current_user)
      base_price.round
    else
      (base_price * 0.90).round
    end
  end
  
  # Calculate tax to pay to system owner (10% of the spread)
  # Called after a trade by a non-owner
  def pay_owner_tax(base_price, quantity, trade_type)
    return unless @system.owned? && !@system.owned_by?(current_user)
    
    # Spread is 10% of base price
    spread_per_unit = (base_price * 0.10).round
    # Tax is 10% of the spread (1% of base price effectively)
    tax_per_unit = (spread_per_unit * 0.10).round
    total_tax = tax_per_unit * quantity
    
    return if total_tax <= 0
    
    @system.owner.update!(credits: @system.owner.credits + total_tax)
    total_tax
  end
  
  # Get actual inventory from MarketInventory model
  def calculate_inventory(commodity)
    inventory = MarketInventory.for_system_commodity(@system, commodity)
    inventory&.quantity || 0
  end
  
  # Trend is based on price delta magnitude
  # Requires significant movement (±10 cents) to show a trend
  def calculate_trend(commodity)
    PriceDelta.trend_for(@system, commodity)
  end
end
