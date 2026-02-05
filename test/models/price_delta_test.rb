# frozen_string_literal: true

require "test_helper"

class PriceDeltaTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @system = System.discover_at(x: 100, y: 200, z: 300, user: @user)
  end

  # ==========================================
  # Model Validations
  # ==========================================

  test "validates presence of system" do
    delta = PriceDelta.new(commodity: "iron", delta_cents: 100)
    assert_not delta.valid?
    assert_includes delta.errors[:system], "must exist"
  end

  test "validates presence of commodity" do
    delta = PriceDelta.new(system: @system, delta_cents: 100)
    assert_not delta.valid?
    assert_includes delta.errors[:commodity], "can't be blank"
  end

  test "validates presence of delta_cents" do
    # Note: delta_cents has a default of 0 in the database, 
    # so this validation only matters if explicitly set to nil
    delta = PriceDelta.new(system: @system, commodity: "iron", delta_cents: nil)
    assert_not delta.valid?
    assert_includes delta.errors[:delta_cents], "can't be blank"
  end

  test "validates uniqueness of commodity per system" do
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 100)
    duplicate = PriceDelta.new(system: @system, commodity: "iron", delta_cents: 50)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:commodity], "has already been taken"
  end

  test "allows same commodity in different systems" do
    system2 = System.discover_at(x: 101, y: 201, z: 301, user: @user)
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 100)
    delta2 = PriceDelta.new(system: system2, commodity: "iron", delta_cents: 50)
    assert delta2.valid?
  end

  test "allows positive and negative deltas" do
    positive = PriceDelta.new(system: @system, commodity: "iron", delta_cents: 500)
    assert positive.valid?

    negative = PriceDelta.new(system: @system, commodity: "copper", delta_cents: -300)
    assert negative.valid?
  end

  # ==========================================
  # Price Calculations
  # ==========================================

  test "current_price returns base plus delta" do
    base_prices = @system.properties["base_prices"]
    base_iron = base_prices["iron"]

    delta = PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 500)
    assert_equal base_iron + 500, delta.current_price
  end

  test "current_price with negative delta" do
    base_prices = @system.properties["base_prices"]
    base_iron = base_prices["iron"]

    # Create a small negative delta (price drops but stays above 1)
    delta = PriceDelta.create!(system: @system, commodity: "iron", delta_cents: -3)
    assert_equal base_iron - 3, delta.current_price
  end

  test "current_price never goes below 1" do
    base_prices = @system.properties["base_prices"]
    base_iron = base_prices["iron"]

    # Create a huge negative delta that would make price negative
    delta = PriceDelta.create!(system: @system, commodity: "iron", delta_cents: -999999)
    assert_equal 1, delta.current_price
  end

  # ==========================================
  # System Integration
  # ==========================================

  test "system can get current price for commodity" do
    base_prices = @system.properties["base_prices"]
    base_iron = base_prices["iron"]

    # No delta yet - should return base price
    assert_equal base_iron, @system.current_price("iron")

    # Add delta
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 200)
    assert_equal base_iron + 200, @system.current_price("iron")
  end

  test "system returns nil for unknown commodity" do
    assert_nil @system.current_price("nonexistent_commodity")
  end

  test "system can get all current prices" do
    base_prices = @system.properties["base_prices"]
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 100)
    PriceDelta.create!(system: @system, commodity: "fuel", delta_cents: -5)

    current_prices = @system.current_prices
    assert_equal base_prices["iron"] + 100, current_prices["iron"]
    assert_equal base_prices["fuel"] - 5, current_prices["fuel"]
    assert_equal base_prices["gold"], current_prices["gold"] # No delta
  end

  # ==========================================
  # Delta Application (Trades)
  # ==========================================

  test "apply_delta creates new record if none exists" do
    assert_difference "PriceDelta.count", 1 do
      PriceDelta.apply_delta(@system, "iron", 100)
    end

    delta = PriceDelta.find_by(system: @system, commodity: "iron")
    assert_equal 100, delta.delta_cents
  end

  test "apply_delta updates existing record" do
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 100)

    assert_no_difference "PriceDelta.count" do
      PriceDelta.apply_delta(@system, "iron", 50)
    end

    delta = PriceDelta.find_by(system: @system, commodity: "iron")
    assert_equal 150, delta.delta_cents
  end

  test "apply_delta with negative value decreases price" do
    PriceDelta.create!(system: @system, commodity: "iron", delta_cents: 100)

    PriceDelta.apply_delta(@system, "iron", -30)

    delta = PriceDelta.find_by(system: @system, commodity: "iron")
    assert_equal 70, delta.delta_cents
  end

  # ==========================================
  # Price Formula Verification
  # ==========================================

  test "base price is calculated from seed without DB" do
    # This should work without any DB lookups
    base_prices = ProceduralGeneration.generate_base_prices(12345)
    assert base_prices.is_a?(Hash)
    assert base_prices[:iron].positive?
  end

  test "base prices are deterministic" do
    price1 = ProceduralGeneration.generate_base_prices(99999)
    price2 = ProceduralGeneration.generate_base_prices(99999)
    assert_equal price1, price2
  end

  test "different seeds produce different prices" do
    price1 = ProceduralGeneration.generate_base_prices(11111)
    price2 = ProceduralGeneration.generate_base_prices(22222)
    # At least some prices should differ
    assert_not_equal price1, price2
  end
end
