require "application_system_test_case"

class BotTradingTest < ApplicationSystemTestCase
  # ==========================================
  # Trading Loop Integration Test
  #
  # Tests the complete trading loop:
  # 1. User with credits buys a ship
  # 2. Navigates to a system with cheap goods
  # 3. Buys goods
  # 4. Travels to another system
  # 5. Sells goods for profit
  # ==========================================

  setup do
    # Create a user with sufficient credits for trading
    @user = User.create!(
      email: "bot_trader_#{SecureRandom.hex(4)}@test.com",
      name: "Bot Trader",
      short_id: "u-bt#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 5000
    )

    # Create two systems with price differences
    @buy_system = System.create!(
      x: 10, y: 0, z: 0,
      name: "Cheap System",
      short_id: "sy-ch#{SecureRandom.hex(2)}",
      properties: {
        "star_type" => "yellow_dwarf",
        "planet_count" => 3,
        "hazard_level" => 10,
        "base_prices" => {
          "ore" => 50,      # Cheap here
          "electronics" => 200,
          "fuel" => 80
        }
      }
    )

    @sell_system = System.create!(
      x: 11, y: 0, z: 0,
      name: "Rich System",
      short_id: "sy-ri#{SecureRandom.hex(2)}",
      properties: {
        "star_type" => "yellow_dwarf",
        "planet_count" => 5,
        "hazard_level" => 5,
        "base_prices" => {
          "ore" => 150,     # Expensive here - profit opportunity!
          "electronics" => 100,
          "fuel" => 80
        }
      }
    )

    # Create a ship for the user
    @ship = Ship.create!(
      name: "Trading Vessel",
      short_id: "sh-tv#{SecureRandom.hex(2)}",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 100,
      status: "docked",
      current_system: @buy_system,
      cargo: {},
      ship_attributes: { "cargo_capacity" => 100 }
    )
  end

  # ==========================================
  # Test: Complete profitable trading loop
  # ==========================================
  test "bot completes a profitable trading loop" do
    initial_credits = @user.credits

    # Step 1: Verify user owns the ship
    assert_includes @user.ships, @ship
    assert_equal @buy_system, @ship.current_system

    # Step 2: Check market prices at buy system
    buy_price = @buy_system.current_price("ore")
    assert_equal 50, buy_price, "Ore should cost 50 at buy system"

    # Step 3: Buy ore at cheap price
    quantity_to_buy = 50
    total_buy_cost = buy_price * quantity_to_buy

    # Deduct credits and add cargo
    @user.update!(credits: @user.credits - total_buy_cost)
    result = @ship.add_cargo!("ore", quantity_to_buy)

    assert result.success?, "Should successfully add cargo"
    assert_equal quantity_to_buy, @ship.cargo_quantity_for("ore")
    assert_equal initial_credits - total_buy_cost, @user.credits

    # Step 4: Travel to sell system
    travel_result = @ship.travel_to!(@sell_system, intent: :trade)

    assert travel_result.success?, "Travel should succeed: #{travel_result.error}"
    assert_equal "in_transit", @ship.status

    # Simulate arrival (in real game this would be time-based)
    @ship.update!(
      status: "docked",
      current_system: @sell_system,
      destination_system: nil,
      arrival_at: nil,
      system_intent: "trade"
    )

    assert_equal @sell_system, @ship.reload.current_system

    # Step 5: Check sell price and sell goods
    sell_price = @sell_system.current_price("ore")
    assert_equal 150, sell_price, "Ore should sell for 150 at sell system"

    total_sell_revenue = sell_price * quantity_to_buy
    credits_before_sell = @user.credits

    # Remove cargo and add credits
    remove_result = @ship.remove_cargo!("ore", quantity_to_buy)
    assert remove_result.success?, "Should successfully remove cargo"

    @user.update!(credits: @user.credits + total_sell_revenue)

    # Step 6: Verify profit
    expected_profit = (sell_price - buy_price) * quantity_to_buy
    actual_profit = @user.credits - initial_credits

    assert_equal expected_profit, actual_profit,
      "Expected profit of #{expected_profit}, got #{actual_profit}"
    assert actual_profit > 0, "Trade should be profitable"

    # Verify final state
    assert_equal 0, @ship.cargo_quantity_for("ore"), "Cargo should be empty"
    assert @user.credits > initial_credits, "User should have more credits than before"
  end

  # ==========================================
  # Test: Trading with insufficient credits fails
  # ==========================================
  test "bot cannot trade without sufficient credits" do
    # Give user very few credits
    @user.update!(credits: 10)

    buy_price = @buy_system.current_price("ore")
    quantity_to_buy = 50
    total_cost = buy_price * quantity_to_buy

    assert total_cost > @user.credits, "Test setup: cost should exceed credits"

    # Attempt to buy should fail
    assert @user.credits < total_cost, "User should not have enough credits"
  end

  # ==========================================
  # Test: Trading with insufficient cargo space fails
  # ==========================================
  test "bot cannot buy more than cargo capacity" do
    # Ship has 100 cargo capacity
    quantity_over_capacity = 150

    result = @ship.add_cargo!("ore", quantity_over_capacity)

    assert_not result.success?, "Adding cargo over capacity should fail"
    assert_match /capacity/i, result.error
  end

  # ==========================================
  # Test: Trading requires being docked
  # ==========================================
  test "bot cannot trade while in transit" do
    # Start travel
    @ship.travel_to!(@sell_system, intent: :trade)

    assert_equal "in_transit", @ship.status

    # Attempting another travel while in transit should fail
    result = @ship.travel_to!(@buy_system, intent: :trade)

    assert_not result.success?
    assert_match /already in transit/i, result.error
  end

  # ==========================================
  # Test: Price delta affects trading
  # ==========================================
  test "price deltas affect profit margins" do
    # Apply a price delta (market has been depleted, price goes up)
    PriceDelta.apply_delta(@buy_system, "ore", 30)

    new_buy_price = @buy_system.current_price("ore")
    assert_equal 80, new_buy_price, "Price should be base (50) + delta (30)"

    sell_price = @sell_system.current_price("ore")

    # Profit margin is now smaller
    profit_per_unit = sell_price - new_buy_price
    assert_equal 70, profit_per_unit, "Profit margin reduced due to delta"
  end

  # ==========================================
  # Test: Multiple commodity types
  # ==========================================
  test "bot can carry multiple commodities" do
    # Add two types of cargo
    @ship.add_cargo!("ore", 30)
    @ship.add_cargo!("electronics", 20)

    assert_equal 30, @ship.cargo_quantity_for("ore")
    assert_equal 20, @ship.cargo_quantity_for("electronics")
    assert_equal 50, @ship.total_cargo_weight
    assert_equal 50, @ship.available_cargo_space
  end

  # ==========================================
  # Test: Fuel consumption during travel
  # ==========================================
  test "travel consumes fuel" do
    initial_fuel = @ship.fuel
    @ship.travel_to!(@sell_system, intent: :trade)

    assert @ship.fuel < initial_fuel, "Fuel should be consumed during travel"
  end

  # ==========================================
  # Test: Cannot travel without fuel
  # ==========================================
  test "bot cannot travel without sufficient fuel" do
    # Drain fuel
    @ship.update!(fuel: 0)

    result = @ship.travel_to!(@sell_system, intent: :trade)

    assert_not result.success?
    assert_match /insufficient fuel/i, result.error
  end
end
