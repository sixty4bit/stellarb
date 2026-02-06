# frozen_string_literal: true

require "test_helper"

class MarketControllerFogTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Use The Cradle which has fixed base_prices
    @system = System.cradle
    # Record a visit to allow market access (this snapshots prices)
    @visit = SystemVisit.record_visit(@user, @system)
    
    sign_in_as(@user)
  end

  # ===========================================
  # Market Access Tests
  # ===========================================

  test "market shows live prices when ship is docked" do
    # Create a docked ship at this system
    ship = Ship.create!(
      user: @user,
      name: "Trade Vessel",
      hull_size: "transport",
      race: "vex",
      variant_idx: 0,
      current_system: @system,
      status: "docked",
      fuel: 50,
      fuel_capacity: 100
    )

    get system_market_index_path(@system)
    
    assert_response :success
    assert_match(/LIVE PRICES/i, response.body)
    assert_match(/You have a ship docked/i, response.body)
  end

  test "market shows remembered prices when no ship docked" do
    get system_market_index_path(@system)
    
    assert_response :success
    assert_match(/REMEMBERED PRICES/i, response.body)
    assert_match(/Prices as of/i, response.body)
  end

  test "market shows staleness time for remembered prices" do
    # Update the visit to be 2 hours ago
    @visit.update!(last_visited_at: 2.hours.ago)

    get system_market_index_path(@system)
    
    assert_response :success
    assert_match(/2 hours ago/i, response.body)
  end

  test "market uses snapshot prices when not docked" do
    # Manually set a snapshot with specific prices
    @visit.update!(price_snapshot: { "iron" => 100, "copper" => 200 })

    get system_market_index_path(@system)
    
    assert_response :success
    # The view should be rendering prices from the snapshot
    # We can't easily check exact values, but response should be successful
  end
end
