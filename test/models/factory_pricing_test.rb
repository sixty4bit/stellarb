# frozen_string_literal: true

require "test_helper"

class FactoryPricingTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    # Create a fresh system with minerals available for testing
    @system = System.create!(
      name: "Test Factory System",
      short_id: "sy-factory-#{SecureRandom.hex(4)}",
      x: rand(1000),
      y: rand(1000),
      z: rand(1000),
      properties: {
        "mineral_distribution" => { "0" => { "minerals" => ["iron", "copper", "silicon"], "abundance" => "high" } },
        "base_prices" => { "iron" => 100, "copper" => 150, "silicon" => 180 }
      }
    )
    # Factory requires a marketplace
    @marketplace = Building.create!(
      user: @user,
      system: @system,
      name: "Test Marketplace",
      function: "civic",
      race: "vex",
      tier: 1,
      status: "active",
      uuid: Building.generate_uuid7
    )
  end

  # ===========================================
  # Factory Specialization Constants
  # ===========================================

  test "FACTORY_SPECIALIZATIONS contains 8 specializations" do
    assert_equal 8, Building::FACTORY_SPECIALIZATIONS.keys.size
  end

  test "FACTORY_SPECIALIZATIONS includes all required specializations" do
    expected = %w[basic electronics structural power propulsion weapons defense advanced]

    expected.each do |spec|
      assert_includes Building::FACTORY_SPECIALIZATIONS.keys, spec,
        "Missing factory specialization: #{spec}"
    end
  end

  test "each factory specialization has inputs and outputs" do
    Building::FACTORY_SPECIALIZATIONS.each do |name, config|
      assert config[:inputs].present?, "#{name} factory missing inputs"
      assert config[:outputs].present?, "#{name} factory missing outputs"
      assert config[:inputs].is_a?(Array), "#{name} factory inputs must be an array"
      assert config[:outputs].is_a?(Array), "#{name} factory outputs must be an array"
    end
  end

  # ===========================================
  # Factory Specialization Validation
  # ===========================================

  test "factory validates specialization is a known specialization" do
    factory = Building.new(
      user: @user,
      system: @system,
      name: "Invalid Factory",
      function: "refining",
      race: "vex",
      tier: 1,
      status: "active",
      specialization: "invalid_specialization",
      uuid: Building.generate_uuid7
    )

    assert_not factory.valid?
    assert_includes factory.errors[:specialization], "must be a valid factory specialization"
  end

  test "factory accepts valid specialization" do
    factory = Building.new(
      user: @user,
      system: @system,
      name: "Basic Factory",
      function: "refining",
      race: "vex",
      tier: 1,
      status: "active",
      specialization: "basic",
      uuid: Building.generate_uuid7
    )

    assert factory.valid?, factory.errors.full_messages.join(", ")
  end

  # ===========================================
  # Factory Input Price Increases (+10-30% by tier)
  # ===========================================

  test "tier 1 factory increases input mineral prices by 10%" do
    factory = create_factory(tier: 1, specialization: "basic")

    # Basic factory uses iron as input
    assert_equal 1.10, factory.input_price_modifier_for("iron")
  end

  test "tier 2 factory increases input mineral prices by 15%" do
    factory = create_factory(tier: 2, specialization: "basic")

    assert_equal 1.15, factory.input_price_modifier_for("iron")
  end

  test "tier 3 factory increases input mineral prices by 20%" do
    factory = create_factory(tier: 3, specialization: "basic")

    assert_equal 1.20, factory.input_price_modifier_for("iron")
  end

  test "tier 4 factory increases input mineral prices by 25%" do
    factory = create_factory(tier: 4, specialization: "basic")

    assert_equal 1.25, factory.input_price_modifier_for("iron")
  end

  test "tier 5 factory increases input mineral prices by 30%" do
    factory = create_factory(tier: 5, specialization: "basic")

    assert_equal 1.30, factory.input_price_modifier_for("iron")
  end

  test "factory only affects input prices for its configured inputs" do
    factory = create_factory(tier: 3, specialization: "basic")

    # Iron is a basic factory input
    assert_equal 1.20, factory.input_price_modifier_for("iron")
    # Silicon is NOT a basic factory input
    assert_equal 1.0, factory.input_price_modifier_for("silicon")
  end

  # ===========================================
  # Factory Output Price Decreases (-5-25% by tier)
  # ===========================================

  test "tier 1 factory decreases output component prices by 5%" do
    factory = create_factory(tier: 1, specialization: "basic")

    # Basic factory outputs basic_components
    assert_equal 0.95, factory.output_price_modifier_for("basic_components")
  end

  test "tier 2 factory decreases output component prices by 10%" do
    factory = create_factory(tier: 2, specialization: "basic")

    assert_equal 0.90, factory.output_price_modifier_for("basic_components")
  end

  test "tier 3 factory decreases output component prices by 15%" do
    factory = create_factory(tier: 3, specialization: "basic")

    assert_equal 0.85, factory.output_price_modifier_for("basic_components")
  end

  test "tier 4 factory decreases output component prices by 20%" do
    factory = create_factory(tier: 4, specialization: "basic")

    assert_equal 0.80, factory.output_price_modifier_for("basic_components")
  end

  test "tier 5 factory decreases output component prices by 25%" do
    factory = create_factory(tier: 5, specialization: "basic")

    assert_equal 0.75, factory.output_price_modifier_for("basic_components")
  end

  test "factory only affects output prices for its configured outputs" do
    factory = create_factory(tier: 3, specialization: "basic")

    # basic_components is a basic factory output
    assert_equal 0.85, factory.output_price_modifier_for("basic_components")
    # electronics_components is NOT a basic factory output
    assert_equal 1.0, factory.output_price_modifier_for("electronics_components")
  end

  # ===========================================
  # price_modifier_for Integration
  # ===========================================

  test "price_modifier_for returns input modifier for input commodities" do
    factory = create_factory(tier: 2, specialization: "basic")

    # Iron is a basic factory input - should get +15% (1.15)
    assert_equal 1.15, factory.price_modifier_for("iron")
  end

  test "price_modifier_for returns output modifier for output commodities" do
    factory = create_factory(tier: 2, specialization: "basic")

    # basic_components is a basic factory output - should get -10% (0.90)
    assert_equal 0.90, factory.price_modifier_for("basic_components")
  end

  test "price_modifier_for returns 1.0 for unrelated commodities" do
    factory = create_factory(tier: 3, specialization: "basic")

    # fuel is neither input nor output for basic factory
    assert_equal 1.0, factory.price_modifier_for("fuel")
  end

  test "disabled factory does not modify prices" do
    factory = create_factory(tier: 3, specialization: "basic")
    factory.update!(disabled_at: Time.current)

    assert_equal 1.0, factory.price_modifier_for("iron")
    assert_equal 1.0, factory.price_modifier_for("basic_components")
  end

  test "non-active factory does not modify prices" do
    factory = create_factory(tier: 3, specialization: "basic")
    factory.update!(status: "under_construction")

    assert_equal 1.0, factory.price_modifier_for("iron")
    assert_equal 1.0, factory.price_modifier_for("basic_components")
  end

  # ===========================================
  # Different Factory Specializations
  # ===========================================

  test "electronics factory affects electronics inputs and outputs" do
    factory = create_factory(tier: 3, specialization: "electronics")

    # Silicon is an electronics factory input
    assert_equal 1.20, factory.input_price_modifier_for("silicon")
    # electronics_components is an electronics factory output
    assert_equal 0.85, factory.output_price_modifier_for("electronics_components")
  end

  test "weapons factory affects weapons inputs and outputs" do
    factory = create_factory(tier: 4, specialization: "weapons")

    # weapons inputs should get +25%
    inputs = Building::FACTORY_SPECIALIZATIONS["weapons"][:inputs]
    inputs.each do |input|
      assert_equal 1.25, factory.input_price_modifier_for(input),
        "Expected 1.25 for weapons input: #{input}"
    end

    # weapons outputs should get -20%
    outputs = Building::FACTORY_SPECIALIZATIONS["weapons"][:outputs]
    outputs.each do |output|
      assert_equal 0.80, factory.output_price_modifier_for(output),
        "Expected 0.80 for weapons output: #{output}"
    end
  end

  test "advanced factory affects advanced inputs and outputs" do
    factory = create_factory(tier: 5, specialization: "advanced")

    # advanced inputs should get +30%
    inputs = Building::FACTORY_SPECIALIZATIONS["advanced"][:inputs]
    inputs.each do |input|
      assert_equal 1.30, factory.input_price_modifier_for(input),
        "Expected 1.30 for advanced input: #{input}"
    end

    # advanced outputs should get -25%
    outputs = Building::FACTORY_SPECIALIZATIONS["advanced"][:outputs]
    outputs.each do |output|
      assert_equal 0.75, factory.output_price_modifier_for(output),
        "Expected 0.75 for advanced output: #{output}"
    end
  end

  # ===========================================
  # Helper Methods
  # ===========================================

  test "factory? returns true for refining buildings" do
    factory = create_factory(tier: 1, specialization: "basic")

    assert factory.factory?
  end

  test "factory? returns false for non-refining buildings" do
    assert_not @marketplace.factory?
  end

  test "factory_inputs returns input commodities for factory" do
    factory = create_factory(tier: 1, specialization: "basic")

    assert_equal Building::FACTORY_SPECIALIZATIONS["basic"][:inputs], factory.factory_inputs
  end

  test "factory_outputs returns output commodities for factory" do
    factory = create_factory(tier: 1, specialization: "basic")

    assert_equal Building::FACTORY_SPECIALIZATIONS["basic"][:outputs], factory.factory_outputs
  end

  test "factory_inputs returns empty array for non-factory" do
    assert_equal [], @marketplace.factory_inputs
  end

  test "factory_outputs returns empty array for non-factory" do
    assert_equal [], @marketplace.factory_outputs
  end

  private

  def create_factory(tier:, specialization:)
    Building.create!(
      user: @user,
      system: @system,
      name: "#{specialization.capitalize} Factory T#{tier}",
      function: "refining",
      race: "vex",
      tier: tier,
      status: "active",
      specialization: specialization,
      uuid: Building.generate_uuid7
    )
  end
end
