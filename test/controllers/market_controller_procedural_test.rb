require "test_helper"

class MarketControllerProceduralTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 10000)
    
    # Create two systems with different base prices
    @system1 = System.create!(
      x: 3, y: 3, z: 0,
      name: "Test System 1",
      short_id: "sys-test1",
      properties: {
        "base_prices" => {
          "iron" => 50,
          "copper" => 75,
          "fuel" => 100
        }
      }
    )
    
    @system2 = System.create!(
      x: 6, y: 3, z: 0,
      name: "Test System 2",
      short_id: "sys-test2",
      properties: {
        "base_prices" => {
          "iron" => 80,
          "copper" => 40,
          "fuel" => 120
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
    end

    # Create marketplaces (civic buildings) in both systems
    # Using tier 5 (1% fee) to minimize fee impact on these pricing-focused tests
    [@system1, @system2].each do |system|
      Building.create!(
        user: @user,
        system: system,
        name: "#{system.name} Market",
        function: "civic",
        race: "vex",
        tier: 5  # 1% fee
      )

      # Create market inventory
      system.base_prices.each do |commodity, _price|
        MarketInventory.create!(
          system: system,
          commodity: commodity,
          quantity: 500,
          max_quantity: 1000,
          restock_rate: 10
        )
      end
    end

    sign_in_as @user
  end
  
  # Fee rate for tier 5 marketplace
  def marketplace_fee_rate
    0.01  # 1%
  end

  # === BUY/SELL WITH REAL PRICES ===
  
  test "buy uses procedural price with 10% spread" do
    initial_credits = @user.credits
    
    # Iron base price in system1 is 50
    # Buy price = 50 * 1.10 = 55
    base_price = @system1.current_price("iron")
    assert_equal 50, base_price, "System1 iron base price should be 50"
    
    expected_buy_price = (base_price * 1.10).round
    assert_equal 55, expected_buy_price
    
    quantity = 10
    base_cost = expected_buy_price * quantity
    # Plus 1% marketplace fee
    marketplace_fee = (base_cost * marketplace_fee_rate).round
    expected_cost = base_cost + marketplace_fee
    
    post buy_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: quantity
    }

    assert_redirected_to system_market_index_path(@system1)
    assert_equal initial_credits - expected_cost, @user.reload.credits,
      "Credits should decrease by buy_price * quantity (#{expected_cost})"
    assert_equal quantity, @ship1.reload.cargo["iron"]
  end

  test "sell uses procedural price with 10% spread" do
    @ship1.update!(cargo: { "iron" => 50 })
    initial_credits = @user.credits

    # Iron base price in system1 is 50
    # Sell price = 50 * 0.90 = 45
    base_price = @system1.current_price("iron")
    expected_sell_price = (base_price * 0.90).round
    assert_equal 45, expected_sell_price

    quantity = 10
    gross_income = expected_sell_price * quantity
    # Minus 1% marketplace fee
    marketplace_fee = (gross_income * marketplace_fee_rate).round
    expected_income = gross_income - marketplace_fee

    post sell_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: quantity
    }

    assert_redirected_to system_market_index_path(@system1)
    assert_equal initial_credits + expected_income, @user.reload.credits,
      "Credits should increase by sell_price * quantity (#{expected_income})"
  end

  test "buying same commodity costs differently in different systems" do
    quantity = 10

    # System1: iron base=50, buy=55, cost=550 + 1% fee = 556
    system1_base = @system1.current_price("iron")
    system1_buy = (system1_base * 1.10).round
    base_cost1 = system1_buy * quantity
    expected_cost1 = base_cost1 + (base_cost1 * marketplace_fee_rate).round

    post buy_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: quantity
    }
    actual_cost1 = 10000 - @user.reload.credits

    assert_equal expected_cost1, actual_cost1,
      "System1 iron cost should be #{expected_cost1}"

    # System2: iron base=80, buy=88, cost=880 + 1% fee = 889
    system2_base = @system2.current_price("iron")
    system2_buy = (system2_base * 1.10).round
    base_cost2 = system2_buy * quantity
    expected_cost2 = base_cost2 + (base_cost2 * marketplace_fee_rate).round

    credits_before = @user.credits
    post buy_system_market_index_path(@system2), params: {
      commodity: "iron",
      quantity: quantity
    }
    actual_cost2 = credits_before - @user.reload.credits

    assert_equal expected_cost2, actual_cost2,
      "System2 iron cost should be #{expected_cost2}"

    assert_not_equal actual_cost1, actual_cost2,
      "Same commodity should cost different amounts in different systems"

    # System2 should be more expensive (base 80 vs 50)
    assert actual_cost2 > actual_cost1,
      "System2 iron (base 80) should cost more than System1 iron (base 50)"
  end

  # === PRICE DELTA INTEGRATION ===

  test "price deltas affect buy price" do
    initial_credits = @user.credits
    quantity = 10

    # Apply a price delta to iron in system1 (+20)
    PriceDelta.apply_delta(@system1, "iron", 20)

    # Base is 50, delta is +20, so current should be 70
    current_price = @system1.current_price("iron")
    assert_equal 70, current_price, "Current price should include delta"

    # Buy = 70 * 1.10 = 77
    expected_buy = (current_price * 1.10).round
    base_cost = expected_buy * quantity
    # Plus 1% marketplace fee
    expected_cost = base_cost + (base_cost * marketplace_fee_rate).round

    post buy_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: quantity
    }

    assert_equal initial_credits - expected_cost, @user.reload.credits,
      "Buy price should include price delta"
  end

  test "price deltas affect sell price" do
    @ship1.update!(cargo: { "iron" => 50 })
    initial_credits = @user.credits
    quantity = 10

    # Apply a price delta to iron in system1 (+20)
    PriceDelta.apply_delta(@system1, "iron", 20)

    # Base is 50, delta is +20, so current should be 70
    current_price = @system1.current_price("iron")
    assert_equal 70, current_price

    # Sell = 70 * 0.90 = 63
    expected_sell = (current_price * 0.90).round
    gross_income = expected_sell * quantity
    # Minus 1% marketplace fee
    expected_income = gross_income - (gross_income * marketplace_fee_rate).round

    post sell_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: quantity
    }

    assert_equal initial_credits + expected_income, @user.reload.credits,
      "Sell price should include price delta"
  end

  # === SPREAD TESTS ===

  test "buy price is higher than sell price creating profit opportunity" do
    # Buy iron at system2 (cheaper base) and sell at system1 (higher base)
    # System2 iron: base=80, buy=88, sell=72
    # System1 iron: base=50, buy=55, sell=45
    # So buy cheap at... wait, system1 is cheaper!
    # System1: buy=55+fee, sell=45-fee
    # System2: buy=88+fee, sell=72-fee

    # Buy at system1 (cheaper) for 55 + fee credits
    post buy_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: 1
    }
    credits_after_buy = @user.reload.credits
    buy_cost = 10000 - credits_after_buy

    # Move iron to ship2 cargo manually for test (simulating trade route)
    @ship2.update!(cargo: { "iron" => 1 })

    # Sell at system2 (higher base) for 72 - fee credits
    post sell_system_market_index_path(@system2), params: {
      commodity: "iron",
      quantity: 1
    }
    sell_income = @user.reload.credits - credits_after_buy

    # Profit should be sell - buy (accounting for fees)
    # With 1% fees: buy ~56, sell ~71, profit ~15
    profit = sell_income - buy_cost
    assert profit > 0, "Should profit from buying low and selling high"
  end

  test "same-system arbitrage is not profitable due to spread" do
    # Buy and sell in same system should lose money (10% spread each way + fees)
    # Buy = base * 1.10 + fee, Sell = base * 0.90 - fee
    # Net: roughly 0.90 / 1.10 = 0.818 (lose ~18%) plus fees

    initial_credits = @user.credits

    # Buy 10 iron at system1
    post buy_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: 10
    }

    # Immediately sell the same 10 iron at system1
    post sell_system_market_index_path(@system1), params: {
      commodity: "iron",
      quantity: 10
    }
    
    final_credits = @user.reload.credits
    
    # Should have lost money - the spread plus fees guarantees this
    assert final_credits < initial_credits,
      "Same-system buy/sell should result in loss due to spread"
    
    # Verify we lost at least 5% - spread is ~18% + fees but price dynamics reduce it
    loss = initial_credits - final_credits
    base_price = @system1.base_prices["iron"]
    transaction_value = (base_price * 1.10).round * 10
    loss_percentage = (loss.to_f / transaction_value) * 100
    
    assert loss_percentage >= 5,
      "Should lose at least 5% to spread (lost #{loss_percentage.round(1)}%)"
  end
end
