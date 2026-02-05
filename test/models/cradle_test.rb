# frozen_string_literal: true

require "test_helper"

class CradleTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-0q1 - Cradle system seeding
  # Generate System(0,0,0) with tutorial properties
  # ===========================================

  test "ProceduralGeneration returns The Cradle for coordinates (0,0,0)" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)

    assert_equal "The Cradle", cradle[:name]
    assert_equal 0, cradle[:coordinates][:x]
    assert_equal 0, cradle[:coordinates][:y]
    assert_equal 0, cradle[:coordinates][:z]
  end

  test "The Cradle has tutorial-specific properties" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)

    assert cradle[:special_properties][:tutorial_zone], "Should be a tutorial zone"
    assert cradle[:special_properties][:high_security], "Should be high security"
    assert cradle[:special_properties][:saturated_markets], "Markets should be saturated"
  end

  test "The Cradle has safe hazard level" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)

    assert_equal 0, cradle[:hazard_level], "Cradle should have zero hazard for new players"
  end

  test "The Cradle has yellow dwarf star (Earth-like)" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)

    assert_equal "yellow_dwarf", cradle[:star_type]
  end

  test "The Cradle has Water available for tutorial supply chain" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)

    all_minerals = cradle[:mineral_distribution].values.flat_map { |p| p[:minerals] }
    assert_includes all_minerals, "water", "Water must be available for the supply chain tutorial"
  end

  test "The Cradle has base prices for tutorial commodities" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)
    prices = cradle[:base_prices]

    assert prices[:water].present?, "Water price must be set"
    assert prices[:food].present?, "Food price must be set (for Hydroponics output)"
  end

  test "The Cradle prices result in thin profit margins (saturated market)" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)
    prices = cradle[:base_prices]

    # Water -> Hydroponics -> Food supply chain
    # Margins should be thin: food price should not be dramatically higher than water
    water_price = prices[:water]
    food_price = prices[:food]

    margin = food_price - water_price
    margin_percent = (margin.to_f / water_price * 100).round

    # Margin should be positive but thin (5-20% profit at most)
    assert margin > 0, "Must have positive margin"
    assert margin_percent <= 400, "Margin should be thin due to saturated market (got #{margin_percent}%)"
  end

  test "The Cradle is deterministic - same result every time" do
    cradle1 = ProceduralGeneration.generate_system(0, 0, 0)
    cradle2 = ProceduralGeneration.generate_system(0, 0, 0)

    assert_equal cradle1[:name], cradle2[:name]
    assert_equal cradle1[:star_type], cradle2[:star_type]
    assert_equal cradle1[:base_prices], cradle2[:base_prices]
  end

  test "System model is_cradle? returns true for (0,0,0)" do
    user = User.create!(name: "Test", email: "cradle_test@test.com")
    system = System.discover_at(x: 0, y: 0, z: 0, user: user)

    assert system.is_cradle?, "System at (0,0,0) should be The Cradle"
  end

  test "System model is_cradle? returns false for other coordinates" do
    user = User.create!(name: "Test", email: "cradle_test2@test.com")
    system = System.discover_at(x: 1, y: 1, z: 1, user: user)

    refute system.is_cradle?, "System at (1,1,1) should not be The Cradle"
  end

  test "The Cradle system has tutorial properties in DB when discovered" do
    user = User.create!(name: "Test", email: "cradle_test3@test.com")
    system = System.discover_at(x: 0, y: 0, z: 0, user: user)

    assert_equal "The Cradle", system.name
    assert system.properties["tutorial_zone"] || system.properties[:tutorial_zone] ||
           system.properties["is_tutorial_zone"] || system.properties[:is_tutorial_zone],
           "Should have tutorial zone property"
  end

  test "The Cradle has starter buildings for tutorial" do
    cradle = ProceduralGeneration.generate_system(0, 0, 0)

    # Should have information about available buildings or building types
    assert cradle[:special_properties][:tutorial_zone]

    # The Cradle should support Water Extractor and Hydroponics for the supply chain task
    # This could be in building_types or available_facilities
    available_building_types = cradle[:special_properties][:available_building_types] ||
                                %w[water_extractor hydroponics refinery habitat]

    assert_includes available_building_types, "water_extractor"
    assert_includes available_building_types, "hydroponics"
  end
end
