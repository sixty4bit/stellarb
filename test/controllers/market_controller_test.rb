require "test_helper"

class MarketControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 5000)
    @system = System.cradle
    
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
    
    sign_in_as @user
  end

  test "index shows market data for visited system" do
    get system_market_index_path(@system)
    
    assert_response :success
  end

  test "buy adds commodity to ship cargo" do
    post buy_system_market_index_path(@system), params: {
      ship_id: @ship.id,
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
    expected_cost = quantity * 11
    
    post buy_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "iron",
      quantity: quantity
    }
    
    assert_equal initial_credits - expected_cost, @user.reload.credits
  end

  test "buy fails if insufficient credits" do
    @user.update!(credits: 10)
    
    post buy_system_market_index_path(@system), params: {
      ship_id: @ship.id,
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
      ship_id: @ship.id,
      commodity: "water",
      quantity: 10 # Needs 10 space
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_match /cargo.*space/i, flash[:alert]
  end

  test "sell removes commodity from ship cargo" do
    @ship.update!(cargo: { "iron" => 50 })
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
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
    expected_income = quantity * 9
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "iron",
      quantity: quantity
    }
    
    assert_equal initial_credits + expected_income, @user.reload.credits
  end

  test "sell fails if insufficient cargo" do
    @ship.update!(cargo: { "iron" => 5 })
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
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
      ship_id: @ship.id,
      commodity: "copper",
      quantity: 5
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_match /don't have/i, flash[:alert]
  end
end
