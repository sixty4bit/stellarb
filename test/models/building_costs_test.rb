# frozen_string_literal: true

require "test_helper"

class BuildingCostsTest < ActiveSupport::TestCase
  # ===========================================
  # Building Cost Configuration
  # ===========================================

  test "BUILDING_COSTS constant exists" do
    assert Building::BUILDING_COSTS.is_a?(Hash)
  end

  test "has costs for each function type" do
    Building::FUNCTIONS.each do |function|
      assert Building::BUILDING_COSTS.key?(function),
        "Missing cost for function: #{function}"
    end
  end

  test "each function has base_credits cost for each tier" do
    Building::FUNCTIONS.each do |function|
      cost_data = Building::BUILDING_COSTS[function]
      (1..5).each do |tier|
        assert cost_data[tier].is_a?(Integer),
          "#{function} tier #{tier} missing cost"
        assert cost_data[tier] > 0,
          "#{function} tier #{tier} cost should be positive"
      end
    end
  end

  test "costs scale with tier" do
    Building::FUNCTIONS.each do |function|
      cost_data = Building::BUILDING_COSTS[function]
      (1..4).each do |tier|
        assert cost_data[tier] < cost_data[tier + 1],
          "#{function} tier #{tier} should cost less than tier #{tier + 1}"
      end
    end
  end

  # ===========================================
  # Building Cost Calculations
  # ===========================================

  test "cost_for calculates base cost for function and tier" do
    cost = Building.cost_for(function: "extraction", tier: 1, race: "vex")
    assert cost.is_a?(Integer)
    assert cost > 0
  end

  test "cost_for applies racial modifier" do
    vex_cost = Building.cost_for(function: "extraction", tier: 1, race: "vex")
    krog_cost = Building.cost_for(function: "extraction", tier: 1, race: "krog")
    # Different races may have different modifiers
    assert vex_cost > 0
    assert krog_cost > 0
  end

  test "cost_for raises for invalid function" do
    assert_raises(ArgumentError) do
      Building.cost_for(function: "invalid", tier: 1, race: "vex")
    end
  end

  test "cost_for raises for invalid race" do
    assert_raises(ArgumentError) do
      Building.cost_for(function: "extraction", tier: 1, race: "invalid")
    end
  end

  test "cost_for raises for invalid tier" do
    assert_raises(ArgumentError) do
      Building.cost_for(function: "extraction", tier: 0, race: "vex")
    end
    assert_raises(ArgumentError) do
      Building.cost_for(function: "extraction", tier: 6, race: "vex")
    end
  end

  # ===========================================
  # Constructable Building Types
  # ===========================================

  test "constructable_types returns array of building configurations" do
    types = Building.constructable_types
    assert types.is_a?(Array)
    assert types.any?
  end

  test "constructable types include all functions races and tiers" do
    types = Building.constructable_types
    
    Building::FUNCTIONS.each do |function|
      Building::RACES.each do |race|
        (1..5).each do |tier|
          matching = types.find { |t| 
            t[:function] == function && t[:race] == race && t[:tier] == tier 
          }
          assert matching, "Missing constructable type: #{race} #{function} tier #{tier}"
        end
      end
    end
  end

  test "each constructable type has required fields" do
    types = Building.constructable_types
    
    types.each do |type|
      assert type[:function].present?, "Missing function"
      assert type[:race].present?, "Missing race"
      assert type[:tier].is_a?(Integer), "Missing or invalid tier"
      assert type[:cost].is_a?(Integer), "Missing or invalid cost"
      assert type[:name].present?, "Missing name"
    end
  end

  # ===========================================
  # User Can Afford Check
  # ===========================================

  test "user can afford cheap building with sufficient credits" do
    user = users(:pilot)
    user.update!(credits: 10000)
    
    assert user.can_afford_building?(function: "extraction", tier: 1, race: "vex")
  end

  test "user cannot afford expensive building with insufficient credits" do
    user = users(:pilot)
    user.update!(credits: 100)
    
    refute user.can_afford_building?(function: "defense", tier: 5, race: "krog")
  end

  test "deduct_building_cost removes credits from user" do
    user = users(:pilot)
    user.update!(credits: 10000)
    
    cost = Building.cost_for(function: "extraction", tier: 1, race: "vex")
    user.deduct_building_cost!(function: "extraction", tier: 1, race: "vex")
    
    assert_equal 10000 - cost, user.credits
  end

  test "deduct_building_cost raises if insufficient credits" do
    user = users(:pilot)
    user.update!(credits: 10)
    
    assert_raises(User::InsufficientCreditsError) do
      user.deduct_building_cost!(function: "defense", tier: 5, race: "krog")
    end
  end
end
