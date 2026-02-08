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
      base_price = get_commodity_price(commodity)
      tax_paid = pay_owner_tax(base_price, quantity, :buy)
      
      # Simulate market demand - buying drives prices up
      PriceDelta.simulate_buy(@system, commodity, quantity)
    end

    notice = "Purchased #{quantity} #{commodity} for #{total_cost} credits"
    notice += " (#{marketplace_fee} cr marketplace fee)" if marketplace_fee > 0
    notice += " (#{tax_paid} cr tax to system owner)" if tax_paid

    respond_to do |format|
      format.turbo_stream do
        current_user.reload
        render turbo_stream: [
          turbo_stream.replace("user_credits", partial: "shared/credits"),
          turbo_stream.update("flash_messages", partial: "shared/flash_message", locals: { message: notice, type: "notice" })
        ]
      end
      format.html { redirect_to system_market_index_path(@system), notice: notice }
    end
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
      base_price = get_commodity_price(commodity)
      tax_paid = pay_owner_tax(base_price, quantity, :sell)
      
      # Simulate market supply - selling drives prices down
      PriceDelta.simulate_sell(@system, commodity, quantity)
    end

    notice = "Sold #{quantity} #{commodity} for #{net_income} credits"
    notice += " (#{marketplace_fee} cr marketplace fee)" if marketplace_fee > 0
    notice += " (#{tax_paid} cr tax to system owner)" if tax_paid

    respond_to do |format|
      format.turbo_stream do
        current_user.reload
        render turbo_stream: [
          turbo_stream.replace("user_credits", partial: "shared/credits"),
          turbo_stream.update("flash_messages", partial: "shared/flash_message", locals: { message: notice, type: "notice" })
        ]
      end
      format.html { redirect_to system_market_index_path(@system), notice: notice }
    end
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
    @system = System.find_by!(short_id: params[:system_id]) rescue System.find(params[:system_id])
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
    # Get available minerals based on system type and distance from Cradle
    available_minerals = MineralAvailability.for_system(
      star_type: @system.properties&.dig("star_type") || "yellow_dwarf",
      x: @system.x,
      y: @system.y,
      z: @system.z
    )
    
    # Filter to only available minerals and include tier/category
    market_items = available_minerals.map do |mineral|
      commodity = mineral[:name]
      
      # Get full price breakdown for this commodity
      breakdown = if @has_ship_docked
        @system.price_breakdown_for(commodity)
      else
        # For snapshot prices, construct a simpler breakdown
        snapshot_price = @system_visit&.remembered_prices&.dig(commodity.to_s) || mineral[:base_price]
        {
          base_price: mineral[:base_price],
          abundance_modifier: 1.0,
          after_abundance: mineral[:base_price],
          building_effects: [],
          delta: 0,
          final_price: snapshot_price,
          stale: true
        }
      end
      
      # Final price for buy/sell calculations
      final_price = breakdown&.dig(:final_price) || mineral[:base_price]
      
      {
        commodity: commodity.to_s,
        buy_price: calculate_buy_price(final_price),
        sell_price: calculate_sell_price(final_price),
        inventory: calculate_inventory(commodity),
        trend: calculate_trend(commodity),
        tier: mineral[:tier],
        category: mineral[:category],
        commodity_type: :mineral,
        breakdown: breakdown
      }
    end
    
    # Add components from operational factories in this system
    market_items + generate_component_market_data
  end
  
  # Generate market data for components produced by factories in this system
  # Components only appear when a matching factory exists
  def generate_component_market_data
    operational_factories = @system.buildings
      .where(function: "refining")
      .select(&:operational?)
    
    return [] if operational_factories.empty?
    
    operational_factories.flat_map do |factory|
      specialization = factory.specialization
      next [] unless specialization
      
      # Get components produced by this factory specialization
      component_names = FactorySpecializations.produces(specialization)
      
      component_names.map do |component_name|
        component = Components.find(component_name)
        next unless component
        
        base_price = Components.base_price(component_name)
        
        # Apply factory output price modifier (decreases price based on tier)
        price_modifier = factory.output_price_modifier_for(component_name)
        final_price = (base_price * price_modifier).round
        
        # Ensure/create inventory for this component with tier-based stock
        ensure_component_inventory(component_name, factory.tier)
        
        {
          commodity: component_name,
          buy_price: calculate_buy_price(final_price),
          sell_price: calculate_sell_price(final_price),
          inventory: calculate_inventory(component_name),
          trend: calculate_trend(component_name),
          tier: nil, # Components don't have mineral tiers
          category: component[:category],
          commodity_type: :component,
          breakdown: {
            base_price: base_price,
            abundance_modifier: 1.0,
            after_abundance: base_price,
            building_effects: [{
              building_name: factory.name,
              modifier: price_modifier,
              price_after: final_price
            }],
            delta: 0,
            final_price: final_price
          }
        }
      end.compact
    end
  end
  
  # Ensure market inventory exists for a component, with tier-based stock levels
  # Higher factory tier = more stock. Updates existing inventory if tier increased.
  def ensure_component_inventory(component_name, factory_tier)
    # Base stock scales with factory tier
    # T1: 20, T2: 50, T3: 100, T4: 200, T5: 400
    base_stock = case factory_tier
    when 1 then 20
    when 2 then 50
    when 3 then 100
    when 4 then 200
    when 5 then 400
    else 20
    end
    
    max_stock = base_stock * 2
    restock = [factory_tier * 2, 10].max
    
    existing = MarketInventory.find_by(system: @system, commodity: component_name)
    
    if existing
      # Update if factory tier has increased (higher max = higher tier)
      if max_stock > existing.max_quantity
        existing.update!(
          quantity: [existing.quantity, base_stock].max,
          max_quantity: max_stock,
          restock_rate: restock
        )
      end
    else
      MarketInventory.create!(
        system: @system,
        commodity: component_name,
        quantity: base_stock,
        max_quantity: max_stock,
        restock_rate: restock
      )
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
  
  # Get the current price for a commodity, with fallback to Minerals module
  # @param commodity [String] The commodity name
  # @return [Integer] Current price
  def get_commodity_price(commodity)
    price = @system.current_price(commodity)
    return price if price
    
    # Fall back to Minerals module base price
    mineral = Minerals.find(commodity)
    mineral&.fetch(:base_price, nil)
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
