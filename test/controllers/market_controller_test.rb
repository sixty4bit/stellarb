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
      commodity: "ore",
      quantity: 10
    }
    
    assert_redirected_to system_market_index_path(@system)
    @ship.reload
    assert_equal 10, @ship.cargo["ore"]
  end

  test "buy deducts credits from user" do
    initial_credits = @user.credits
    quantity = 10
    # Ore buy price is 50 from generate_market_data
    expected_cost = quantity * 50
    
    post buy_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "ore",
      quantity: quantity
    }
    
    assert_equal initial_credits - expected_cost, @user.reload.credits
  end

  test "buy fails if insufficient credits" do
    @user.update!(credits: 10)
    
    post buy_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "electronics", # 200 per unit
      quantity: 10
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_match /insufficient credits/i, flash[:alert]
    assert_nil @ship.reload.cargo["electronics"]
  end

  test "buy fails if insufficient cargo space" do
    @ship.update!(cargo: { "ore" => 195 }) # Only 5 space left
    
    post buy_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "water",
      quantity: 10 # Needs 10 space
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_match /cargo.*space/i, flash[:alert]
  end

  test "sell removes commodity from ship cargo" do
    @ship.update!(cargo: { "ore" => 50 })
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "ore",
      quantity: 20
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_equal 30, @ship.reload.cargo["ore"]
  end

  test "sell adds credits to user" do
    @ship.update!(cargo: { "ore" => 50 })
    initial_credits = @user.credits
    quantity = 10
    # Ore sell price is 45 from generate_market_data
    expected_income = quantity * 45
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "ore",
      quantity: quantity
    }
    
    assert_equal initial_credits + expected_income, @user.reload.credits
  end

  test "sell fails if insufficient cargo" do
    @ship.update!(cargo: { "ore" => 5 })
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "ore",
      quantity: 10
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_match /insufficient/i, flash[:alert]
    assert_equal 5, @ship.reload.cargo["ore"] # Unchanged
  end

  test "sell fails for commodity not in cargo" do
    @ship.update!(cargo: {})
    
    post sell_system_market_index_path(@system), params: {
      ship_id: @ship.id,
      commodity: "electronics",
      quantity: 5
    }
    
    assert_redirected_to system_market_index_path(@system)
    assert_match /don't have/i, flash[:alert]
  end
end
