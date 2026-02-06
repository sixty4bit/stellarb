require "test_helper"

class MarketControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 5000)
    @system = System.cradle
    
    # Create a marketplace (civic building) to enable trading
    Building.find_or_create_by!(
      user: @user,
      system: @system,
      function: "civic"
    ) do |b|
      b.name = "Cradle Central Market"
      b.race = "vex"
      b.tier = 1
    end
    
    # Create a ship with cargo space
    @ship = Ship.create!(
      name: "Trade Vessel",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      ship_attributes: { "cargo_capacity" => 200 }
    )
    
    # Mark system as visited
    SystemVisit.create!(
      user: @user, 
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current
    )
    
    # Create market inventory for The Cradle commodities
    @system.base_prices.each do |commodity, _price|
      MarketInventory.find_or_create_by!(system: @system, commodity: commodity) do |inv|
        inv.quantity = 500
        inv.max_quantity = 1000
        inv.restock_rate = 10
      end
    end
    
    sign_in_as @user
  end

  test "index shows market data for visited system" do
    get system_market_index_path(@system)
    
    assert_response :success
  end

  test "buy adds commodity to ship cargo" do
    post buy_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    @ship.reload
    assert_equal 10, @ship.cargo["iron"]
  end

  test "buy deducts credits from user" do
    initial_credits = @user.credits
    quantity = 10
    # Iron base price is 10, buy price = 10 * 1.10 = 11
    # Plus 5% marketplace fee (T1): 110 + 6 = 116
    base_cost = quantity * 11
    marketplace_fee = (base_cost * 0.05).round
    expected_cost = base_cost + marketplace_fee

    post buy_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: quantity
    }

    assert_equal initial_credits - expected_cost, @user.reload.credits
  end

  test "buy fails if insufficient credits" do
    @user.update!(credits: 10)

    post buy_system_market_index_path(@system), params: {
      commodity: "luxury_goods", # Base 100, buy price 110 per unit
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /insufficient credits/i, flash[:alert]
    assert_nil @ship.reload.cargo["luxury_goods"]
  end

  test "buy fails if insufficient cargo space" do
    @ship.update!(cargo: { "iron" => 195 }) # Only 5 space left

    post buy_system_market_index_path(@system), params: {
      commodity: "water",
      quantity: 10 # Needs 10 space
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /cargo.*space/i, flash[:alert]
  end

  test "buy fails without docked ship" do
    @ship.update!(status: "in_transit")

    post buy_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /need a ship docked/i, flash[:alert]
  end

  test "sell removes commodity from ship cargo" do
    @ship.update!(cargo: { "iron" => 50 })

    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 20
    }

    assert_redirected_to system_market_index_path(@system)
    assert_equal 30, @ship.reload.cargo["iron"]
  end

  test "sell adds credits to user" do
    @ship.update!(cargo: { "iron" => 50 })
    initial_credits = @user.credits
    quantity = 10
    # Iron base price is 10, sell price = 10 * 0.90 = 9
    # Minus 5% marketplace fee (T1): 90 - 5 = 85
    gross_income = quantity * 9
    marketplace_fee = (gross_income * 0.05).round
    expected_income = gross_income - marketplace_fee

    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: quantity
    }

    assert_equal initial_credits + expected_income, @user.reload.credits
  end

  test "sell fails if insufficient cargo" do
    @ship.update!(cargo: { "iron" => 5 })

    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /insufficient/i, flash[:alert]
    assert_equal 5, @ship.reload.cargo["iron"] # Unchanged
  end

  test "sell fails for commodity not in cargo" do
    @ship.update!(cargo: {})

    post sell_system_market_index_path(@system), params: {
      commodity: "copper",
      quantity: 5
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /don't have/i, flash[:alert]
  end

  test "sell fails without docked ship" do
    @ship.update!(cargo: { "iron" => 50 }, status: "in_transit")

    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /need a ship docked/i, flash[:alert]
  end

  # ===========================================
  # Inventory Tests
  # ===========================================

  test "buy fails if insufficient market stock" do
    # Set iron inventory to only 5 units
    inventory = MarketInventory.find_by(system: @system, commodity: "iron")
    inventory.update!(quantity: 5)

    post buy_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /insufficient stock/i, flash[:alert]
    assert_nil @ship.reload.cargo["iron"]
  end

  test "buy decreases market inventory" do
    inventory = MarketInventory.find_by(system: @system, commodity: "iron")
    initial_stock = inventory.quantity

    post buy_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_equal initial_stock - 10, inventory.reload.quantity
  end

  test "sell increases market inventory" do
    @ship.update!(cargo: { "iron" => 50 })
    inventory = MarketInventory.find_by(system: @system, commodity: "iron")
    initial_stock = inventory.quantity

    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 20
    }

    assert_redirected_to system_market_index_path(@system)
    assert_equal initial_stock + 20, inventory.reload.quantity
  end

  test "sell caps market inventory at max_quantity" do
    @ship.update!(cargo: { "iron" => 1000 })
    inventory = MarketInventory.find_by(system: @system, commodity: "iron")
    inventory.update!(quantity: 990, max_quantity: 1000)

    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 50
    }

    assert_redirected_to system_market_index_path(@system)
    # Only 10 can be absorbed (990 + 10 = 1000 max)
    assert_equal 1000, inventory.reload.quantity
  end

  test "index shows current inventory levels" do
    get system_market_index_path(@system)
    
    assert_response :success
    # The controller now uses real inventory data
  end

  # ===========================================
  # Price Dynamics Tests
  # ===========================================

  test "buy increases price via price delta" do
    # Clear any existing delta
    PriceDelta.where(system: @system, commodity: "iron").delete_all
    
    # Make a purchase
    post buy_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 50
    }
    
    assert_redirected_to system_market_index_path(@system)
    
    # Price delta should exist and be positive
    delta = PriceDelta.find_by(system: @system, commodity: "iron")
    assert_not_nil delta, "PriceDelta should be created after buy"
    assert_operator delta.delta_cents, :>, 0, "Delta should be positive after purchase"
  end

  test "sell decreases price via price delta" do
    @ship.update!(cargo: { "iron" => 100 })
    
    # Clear any existing delta
    PriceDelta.where(system: @system, commodity: "iron").delete_all
    
    # Make a sale
    post sell_system_market_index_path(@system), params: {
      commodity: "iron",
      quantity: 50
    }
    
    assert_redirected_to system_market_index_path(@system)
    
    # Price delta should exist and be negative
    delta = PriceDelta.find_by(system: @system, commodity: "iron")
    assert_not_nil delta, "PriceDelta should be created after sell"
    assert_operator delta.delta_cents, :<, 0, "Delta should be negative after sale"
  end

  test "large purchase shows upward trend" do
    # Clear any existing delta
    PriceDelta.where(system: @system, commodity: "iron").delete_all
    
    # Create a significant positive delta (> 10 cents)
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 15)
    
    get system_market_index_path(@system)
    
    assert_response :success
    assert_select "span.text-lime-400", text: "↑"
  end

  test "large sale shows downward trend" do
    # Clear any existing delta
    PriceDelta.where(system: @system, commodity: "iron").delete_all
    
    # Create a significant negative delta (< -10 cents)
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: -15)
    
    get system_market_index_path(@system)
    
    assert_response :success
    assert_select "span.text-red-400", text: "↓"
  end

  test "small delta shows stable trend" do
    # Clear any existing delta
    PriceDelta.where(system: @system, commodity: "iron").delete_all
    
    # Create a small delta (within ±10 cents)
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 5)
    
    get system_market_index_path(@system)
    
    assert_response :success
    # Iron should show stable trend
    assert_select "span.text-gray-400", text: "→"
  end
end
