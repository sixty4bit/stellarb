# frozen_string_literal: true

require "test_helper"

class MarketControllerProceduralTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 10000)
    
    # Create two systems with different base prices for minerals
    # Near Cradle (< 100 units) - only Tier 1-2 minerals available
    @system1 = System.create!(
      x: 3, y: 3, z: 0,
      name: "Test System 1",
      short_id: "sys-test1",
      properties: {
        "star_type" => "yellow_dwarf",
        "base_prices" => {
          "Iron" => 50,
          "Copper" => 75,
          "Tungsten" => 100
        }
      }
    )
    
    @system2 = System.create!(
      x: 6, y: 3, z: 0,
      name: "Test System 2",
      short_id: "sys-test2",
      properties: {
        "star_type" => "yellow_dwarf",
        "base_prices" => {
          "Iron" => 80,
          "Copper" => 40,
          "Tungsten" => 120
        }
      }
    )
    
    # Create ships in each system
    @ship1 = Ship.create!(
      name: "Trader 1",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system1,
      ship_attributes: { "cargo_capacity" => 200 }
    )
    
    @ship2 = Ship.create!(
      name: "Trader 2",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system2,
      ship_attributes: { "cargo_capacity" => 200 }
    )
    
    # Mark both systems as visited
    [@system1, @system2].each do |system|
      SystemVisit.create!(
        user: @user,
        system: system,
        first_visited_at: Time.current,
        last_visited_at: Time.current
      )
      
      # Create market inventories for available minerals
      available_minerals = MineralAvailability.for_system(
        star_type: system.properties&.dig("star_type") || "yellow_dwarf",
        x: system.x,
        y: system.y,
        z: system.z
      )
      
      available_minerals.each do |mineral|
        MarketInventory.find_or_create_by!(system: system, commodity: mineral[:name]) do |inv|
          inv.quantity = 500
          inv.max_quantity = 1000
          inv.restock_rate = 10
        end
      end
    end
    
    sign_in_as @user
  end

  # === BUY/SELL WITH REAL PRICES ===
  
  test "buy uses procedural price with 10% spread" do
    initial_credits = @user.credits
    
    # Iron base price in system1 is 50
    # Buy price = 50 * 1.10 = 55
    base_price = @system1.current_price("Iron")
    assert_equal 50, base_price, "System1 Iron base price should be 50"
    
    expected_buy_price = (base_price * 1.10).round
    assert_equal 55, expected_buy_price
    
    quantity = 10
    expected_cost = expected_buy_price * quantity
    
    post buy_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: quantity
    }

    assert_redirected_to system_market_index_path(@system1)
    assert_equal initial_credits - expected_cost, @user.reload.credits,
      "Credits should decrease by buy_price * quantity (#{expected_cost})"
    assert_equal quantity, @ship1.reload.cargo["Iron"]
  end

  test "sell uses procedural price with 10% spread" do
    @ship1.update!(cargo: { "Iron" => 50 })
    initial_credits = @user.credits

    # Iron base price in system1 is 50
    # Sell price = 50 * 0.90 = 45
    base_price = @system1.current_price("Iron")
    expected_sell_price = (base_price * 0.90).round
    assert_equal 45, expected_sell_price

    quantity = 10
    expected_income = expected_sell_price * quantity

    post sell_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: quantity
    }

    assert_redirected_to system_market_index_path(@system1)
    assert_equal initial_credits + expected_income, @user.reload.credits,
      "Credits should increase by sell_price * quantity (#{expected_income})"
  end

  test "buying same commodity costs differently in different systems" do
    quantity = 10

    # System1: Iron base=50, buy=55, cost=550
    system1_base = @system1.current_price("Iron")
    system1_buy = (system1_base * 1.10).round
    expected_cost1 = system1_buy * quantity

    post buy_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: quantity
    }
    actual_cost1 = 10000 - @user.reload.credits

    assert_equal expected_cost1, actual_cost1,
      "System1 Iron cost should be #{expected_cost1}"

    # System2: Iron base=80, buy=88, cost=880
    system2_base = @system2.current_price("Iron")
    system2_buy = (system2_base * 1.10).round
    expected_cost2 = system2_buy * quantity

    credits_before = @user.credits
    post buy_system_market_index_path(@system2), params: {
      commodity: "Iron",
      quantity: quantity
    }
    actual_cost2 = credits_before - @user.reload.credits

    assert_equal expected_cost2, actual_cost2,
      "System2 Iron cost should be #{expected_cost2}"

    assert_not_equal actual_cost1, actual_cost2,
      "Same commodity should cost different amounts in different systems"

    # System2 should be more expensive (base 80 vs 50)
    assert actual_cost2 > actual_cost1,
      "System2 Iron (base 80) should cost more than System1 Iron (base 50)"
  end

  # === PRICE DELTA INTEGRATION ===

  test "price deltas affect buy price" do
    initial_credits = @user.credits
    quantity = 10

    # Apply a price delta to Iron in system1 (+20)
    PriceDelta.apply_delta(@system1, "Iron", 20)

    # Base is 50, delta is +20, so current should be 70
    current_price = @system1.current_price("Iron")
    assert_equal 70, current_price, "Current price should include delta"

    # Buy = 70 * 1.10 = 77
    expected_buy = (current_price * 1.10).round
    expected_cost = expected_buy * quantity

    post buy_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: quantity
    }

    assert_equal initial_credits - expected_cost, @user.reload.credits,
      "Buy price should include price delta"
  end

  test "price deltas affect sell price" do
    @ship1.update!(cargo: { "Iron" => 50 })
    initial_credits = @user.credits
    quantity = 10

    # Apply a price delta to Iron in system1 (+20)
    PriceDelta.apply_delta(@system1, "Iron", 20)

    # Base is 50, delta is +20, so current should be 70
    current_price = @system1.current_price("Iron")
    assert_equal 70, current_price

    # Sell = 70 * 0.90 = 63
    expected_sell = (current_price * 0.90).round
    expected_income = expected_sell * quantity

    post sell_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: quantity
    }

    assert_equal initial_credits + expected_income, @user.reload.credits,
      "Sell price should include price delta"
  end

  # === SPREAD TESTS ===

  test "buy price is higher than sell price creating profit opportunity" do
    # Buy Iron at system1 (cheaper base) and sell at system2 (higher base)
    # System1 Iron: base=50, buy=55, sell=45
    # System2 Iron: base=80, buy=88, sell=72

    # Buy at system1 (cheaper) for 55 credits
    post buy_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: 1
    }
    credits_after_buy = @user.reload.credits
    buy_cost = 10000 - credits_after_buy

    # Move Iron to ship2 cargo manually for test (simulating trade route)
    @ship2.update!(cargo: { "Iron" => 1 })

    # Sell at system2 (higher base) for 72 credits
    post sell_system_market_index_path(@system2), params: {
      commodity: "Iron",
      quantity: 1
    }
    sell_income = @user.reload.credits - credits_after_buy

    # Profit should be sell - buy = 72 - 55 = 17
    profit = sell_income - buy_cost
    assert profit > 0, "Should profit from buying low and selling high"
  end

  test "same-system arbitrage is not profitable due to spread" do
    # Buy and sell in same system should lose money (10% spread each way)
    # Buy = base * 1.10, Sell = base * 0.90
    # Net: 0.90 / 1.10 = 0.818 (lose ~18%)
    # Note: Price dynamics (buying raises price, selling lowers it) slightly
    # reduces the loss, but arbitrage is still not profitable.

    initial_credits = @user.credits

    # Buy 10 Iron at system1
    post buy_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: 10
    }

    # Immediately sell the same 10 Iron at system1
    post sell_system_market_index_path(@system1), params: {
      commodity: "Iron",
      quantity: 10
    }
    
    final_credits = @user.reload.credits
    
    # Should have lost money - the spread guarantees this
    assert final_credits < initial_credits,
      "Same-system buy/sell should result in loss due to spread"
    
    # Verify we lost at least 5% - spread is ~18% but price dynamics reduce it
    loss = initial_credits - final_credits
    base_price = @system1.base_prices["Iron"]
    transaction_value = (base_price * 1.10).round * 10
    loss_percentage = (loss.to_f / transaction_value) * 100
    
    assert loss_percentage >= 5,
      "Should lose at least 5% to spread (lost #{loss_percentage.round(1)}%)"
  end
end
