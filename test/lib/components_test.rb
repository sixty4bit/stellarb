# frozen_string_literal: true

require "test_helper"
require "components"

class ComponentsTest < ActiveSupport::TestCase
  test "has exactly 9 categories" do
    expected_categories = [
      "Basic Parts",
      "Electronics",
      "Structural",
      "Power",
      "Propulsion",
      "Weapons",
      "Defense",
      "Life Support",
      "Advanced"
    ]

    assert_equal expected_categories.sort, Components::CATEGORIES.sort
  end

  test "ALL contains components for each category" do
    Components::CATEGORIES.each do |category|
      components = Components.by_category(category)
      assert components.any?, "Expected at least one component in category: #{category}"
    end
  end

  test "each component has required fields" do
    Components::ALL.each do |component|
      assert component[:name].present?, "Component missing name"
      assert component[:category].present?, "Component missing category"
      assert component[:inputs].is_a?(Hash), "Component #{component[:name]} inputs should be a Hash"
      assert component[:inputs].any?, "Component #{component[:name]} should have at least one input"
    end
  end

  test "each component inputs reference valid minerals" do
    Components::ALL.each do |component|
      component[:inputs].each do |mineral_name, quantity|
        mineral = Minerals.find(mineral_name)
        assert mineral.present?, "Component #{component[:name]} references unknown mineral: #{mineral_name}"
        assert quantity.is_a?(Integer) && quantity > 0, "Component #{component[:name]} has invalid quantity for #{mineral_name}"
      end
    end
  end

  test "find returns component by name" do
    component = Components.find("Iron Plate")
    assert_not_nil component
    assert_equal "Iron Plate", component[:name]
    assert_equal "Basic Parts", component[:category]
  end

  test "find is case-insensitive" do
    assert_equal Components.find("Iron Plate"), Components.find("iron plate")
    assert_equal Components.find("Circuit Board"), Components.find("CIRCUIT BOARD")
  end

  test "find returns nil for unknown component" do
    assert_nil Components.find("Unknown Component")
  end

  test "by_category returns components in that category" do
    basic_parts = Components.by_category("Basic Parts")
    assert basic_parts.any?
    basic_parts.each do |component|
      assert_equal "Basic Parts", component[:category]
    end
  end

  test "by_category returns empty array for unknown category" do
    assert_equal [], Components.by_category("Unknown Category")
  end

  test "base_price calculates from input costs with 1.5 multiplier" do
    # Steel Beam example from source doc: 3 Iron + 1 Carbon
    # Input cost: (3 × 10) + (1 × 8) = 38 credits
    # Base price: 38 × 1.5 = 57 credits
    component = Components.find("Steel Beam")
    assert_not_nil component, "Steel Beam should exist"

    expected_input_cost = component[:inputs].sum do |mineral_name, quantity|
      mineral = Minerals.find(mineral_name)
      mineral[:base_price] * quantity
    end
    expected_price = (expected_input_cost * 1.5).round

    assert_equal expected_price, Components.base_price(component)
  end

  test "base_price class method works with component name" do
    price_by_hash = Components.base_price(Components.find("Iron Plate"))
    price_by_name = Components.base_price("Iron Plate")
    assert_equal price_by_hash, price_by_name
  end

  test "base_price returns nil for unknown component" do
    assert_nil Components.base_price("Unknown Component")
  end

  test "base_price is dynamically calculated from input mineral prices" do
    # Verify price calculation for all components
    Components::ALL.each do |component|
      expected_input_cost = component[:inputs].sum do |mineral_name, quantity|
        Minerals.find(mineral_name)[:base_price] * quantity
      end
      expected_price = (expected_input_cost * 1.5).round

      actual_price = Components.base_price(component)
      assert_equal expected_price, actual_price,
        "#{component[:name]} price should be #{expected_price}, got #{actual_price}"
    end
  end

  test "base_price applies exactly 1.5x multiplier to input cost" do
    # Iron Plate: 2 Iron = 2 × 10 = 20 credits input
    # Expected: 20 × 1.5 = 30 credits
    assert_equal 30, Components.base_price("Iron Plate")

    # Circuit Board: 2 Silicon + 1 Copper = (2 × 18) + (1 × 15) = 51 credits input
    # Expected: 51 × 1.5 = 76.5, rounded to 77 (banker's rounding) or 76
    circuit_board = Components.find("Circuit Board")
    input_cost = (2 * 18) + (1 * 15) # 51
    expected = (input_cost * 1.5).round # 77
    assert_equal expected, Components.base_price(circuit_board)
  end

  test "names returns all component names" do
    names = Components.names
    assert names.include?("Iron Plate")
    assert names.include?("Circuit Board")
    assert_equal Components::ALL.size, names.size
  end

  test "categories have appropriate input minerals based on source doc" do
    # Basic Parts use Tier 1 minerals
    Components.by_category("Basic Parts").each do |component|
      component[:inputs].each do |mineral_name, _qty|
        mineral = Minerals.find(mineral_name)
        assert_includes [:common, :uncommon], mineral[:tier],
          "Basic Parts component #{component[:name]} should use common minerals, not #{mineral_name}"
      end
    end

    # Electronics use Silicon, Copper, Gold
    electronics = Components.by_category("Electronics")
    electronics_minerals = electronics.flat_map { |c| c[:inputs].keys }.uniq
    assert electronics_minerals.include?("Silicon") || electronics_minerals.include?("Copper") || electronics_minerals.include?("Gold"),
      "Electronics should use Silicon, Copper, or Gold"

    # Advanced use futuristic minerals
    advanced = Components.by_category("Advanced")
    advanced.each do |component|
      has_futuristic = component[:inputs].any? do |mineral_name, _qty|
        mineral = Minerals.find(mineral_name)
        mineral[:tier] == :futuristic
      end
      assert has_futuristic, "Advanced component #{component[:name]} should use futuristic minerals"
    end
  end
end
