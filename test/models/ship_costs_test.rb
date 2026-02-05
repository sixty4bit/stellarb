# frozen_string_literal: true

require "test_helper"

class ShipCostsTest < ActiveSupport::TestCase
  # ===========================================
  # Ship Cost Configuration
  # ===========================================

  test "SHIP_COSTS constant exists" do
    assert Ship::SHIP_COSTS.is_a?(Hash)
  end

  test "has costs for each hull size" do
    Ship::HULL_SIZES.each do |hull_size|
      assert Ship::SHIP_COSTS.key?(hull_size),
        "Missing cost for hull size: #{hull_size}"
    end
  end

  test "each hull size has base_credits cost" do
    Ship::HULL_SIZES.each do |hull_size|
      cost_data = Ship::SHIP_COSTS[hull_size]
      assert cost_data[:base_credits].is_a?(Integer),
        "#{hull_size} missing base_credits"
      assert cost_data[:base_credits] > 0,
        "#{hull_size} base_credits should be positive"
    end
  end

  test "costs scale with hull size complexity" do
    # Scout should be cheapest, titan most expensive
    assert Ship::SHIP_COSTS["scout"][:base_credits] < Ship::SHIP_COSTS["frigate"][:base_credits]
    assert Ship::SHIP_COSTS["frigate"][:base_credits] < Ship::SHIP_COSTS["transport"][:base_credits]
    assert Ship::SHIP_COSTS["transport"][:base_credits] < Ship::SHIP_COSTS["cruiser"][:base_credits]
    assert Ship::SHIP_COSTS["cruiser"][:base_credits] < Ship::SHIP_COSTS["titan"][:base_credits]
  end

  # ===========================================
  # Ship Cost Calculations
  # ===========================================

  test "cost_for calculates base cost for hull size" do
    cost = Ship.cost_for(hull_size: "scout", race: "vex")
    assert cost.is_a?(Integer)
    assert cost > 0
  end

  test "cost_for applies racial modifier" do
    vex_cost = Ship.cost_for(hull_size: "transport", race: "vex")
    krog_cost = Ship.cost_for(hull_size: "transport", race: "krog")
    # Different races may have different modifiers
    # At minimum, cost should be calculated
    assert vex_cost > 0
    assert krog_cost > 0
  end

  test "cost_for raises for invalid hull size" do
    assert_raises(ArgumentError) do
      Ship.cost_for(hull_size: "invalid", race: "vex")
    end
  end

  test "cost_for raises for invalid race" do
    assert_raises(ArgumentError) do
      Ship.cost_for(hull_size: "scout", race: "invalid")
    end
  end

  # ===========================================
  # Purchasable Ship Types
  # ===========================================

  test "purchasable_types returns array of ship configurations" do
    types = Ship.purchasable_types
    assert types.is_a?(Array)
    assert types.any?
  end

  test "purchasable types include all hull sizes and races" do
    types = Ship.purchasable_types
    
    Ship::HULL_SIZES.each do |hull_size|
      Ship::RACES.each do |race|
        matching = types.find { |t| t[:hull_size] == hull_size && t[:race] == race }
        assert matching, "Missing purchasable type: #{race} #{hull_size}"
      end
    end
  end

  test "each purchasable type has required fields" do
    types = Ship.purchasable_types
    
    types.each do |type|
      assert type[:hull_size].present?, "Missing hull_size"
      assert type[:race].present?, "Missing race"
      assert type[:cost].is_a?(Integer), "Missing or invalid cost"
      assert type[:name].present?, "Missing name"
    end
  end

  # ===========================================
  # User Can Afford Check
  # ===========================================

  test "user can afford cheap ship with sufficient credits" do
    user = users(:pilot)
    user.update!(credits: 5000)
    
    assert user.can_afford_ship?(hull_size: "scout", race: "vex")
  end

  test "user cannot afford expensive ship with insufficient credits" do
    user = users(:pilot)
    user.update!(credits: 100)
    
    refute user.can_afford_ship?(hull_size: "titan", race: "krog")
  end

  test "deduct_ship_cost removes credits from user" do
    user = users(:pilot)
    user.update!(credits: 5000)
    
    cost = Ship.cost_for(hull_size: "scout", race: "vex")
    user.deduct_ship_cost!(hull_size: "scout", race: "vex")
    
    assert_equal 5000 - cost, user.credits
  end

  test "deduct_ship_cost raises if insufficient credits" do
    user = users(:pilot)
    user.update!(credits: 10)
    
    assert_raises(User::InsufficientCreditsError) do
      user.deduct_ship_cost!(hull_size: "titan", race: "krog")
    end
  end

  # ===========================================
  # Edge Cases: Exact Credit Match
  # ===========================================

  test "user can afford ship when credits exactly match cost" do
    user = users(:pilot)
    cost = Ship.cost_for(hull_size: "scout", race: "vex")
    user.update!(credits: cost)
    
    assert user.can_afford_ship?(hull_size: "scout", race: "vex"),
      "User with exactly #{cost} credits should be able to afford #{cost} credit ship"
  end

  test "deduct_ship_cost works when credits exactly match cost" do
    user = users(:pilot)
    cost = Ship.cost_for(hull_size: "scout", race: "vex")
    user.update!(credits: cost)
    
    # Should not raise - exact match should work
    assert_nothing_raised do
      user.deduct_ship_cost!(hull_size: "scout", race: "vex")
    end
    
    user.reload
    assert_equal 0, user.credits
  end

  test "user cannot afford ship when one credit short" do
    user = users(:pilot)
    cost = Ship.cost_for(hull_size: "scout", race: "vex")
    user.update!(credits: cost - 1)
    
    refute user.can_afford_ship?(hull_size: "scout", race: "vex"),
      "User with #{cost - 1} credits should NOT afford #{cost} credit ship"
  end

  test "deduct_ship_cost raises when one credit short" do
    user = users(:pilot)
    cost = Ship.cost_for(hull_size: "scout", race: "vex")
    user.update!(credits: cost - 1)
    
    assert_raises(User::InsufficientCreditsError) do
      user.deduct_ship_cost!(hull_size: "scout", race: "vex")
    end
  end

  test "racial modifiers are applied correctly for all races" do
    # Vex (1.0x) - base cost
    assert_equal 500, Ship.cost_for(hull_size: "scout", race: "vex")
    
    # Solari (1.1x) - 10% premium
    assert_equal 550, Ship.cost_for(hull_size: "scout", race: "solari")
    
    # Krog (1.15x) - 15% premium
    assert_equal 575, Ship.cost_for(hull_size: "scout", race: "krog")
    
    # Myrmidon (0.9x) - 10% discount
    assert_equal 450, Ship.cost_for(hull_size: "scout", race: "myrmidon")
  end
end
