# frozen_string_literal: true

require "test_helper"

class BuildingPriceModifierTest < ActiveSupport::TestCase
  setup do
    @building = buildings(:mining_facility)
  end

  test "price_modifier_for returns Float" do
    result = @building.price_modifier_for("iron")

    assert_instance_of Float, result
  end

  test "price_modifier_for returns 1.0 by default" do
    assert_equal 1.0, @building.price_modifier_for("iron")
    assert_equal 1.0, @building.price_modifier_for("fuel")
    assert_equal 1.0, @building.price_modifier_for("electronics")
  end

  test "price_modifier_for handles nil commodity gracefully" do
    result = @building.price_modifier_for(nil)

    assert_instance_of Float, result
    assert_equal 1.0, result
  end

  test "price_modifier_for handles unknown commodity gracefully" do
    result = @building.price_modifier_for("nonexistent_commodity_xyz")

    assert_instance_of Float, result
    assert_equal 1.0, result
  end
end

class MinePriceReductionTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    # Create a fresh system with minerals available for mining
    @system = System.create!(
      name: "Test Mining System",
      short_id: "sy-test-#{SecureRandom.hex(4)}",
      x: rand(1000),
      y: rand(1000),
      z: rand(1000),
      properties: {
        "mineral_distribution" => { "0" => { "minerals" => ["iron", "copper"] } }
      }
    )
  end

  test "tier 1 mine reduces price of its mineral by 5%" do
    mine = create_mine(tier: 1, specialization: "iron")

    assert_equal 0.95, mine.price_modifier_for("iron")
  end

  test "tier 2 mine reduces price of its mineral by 10%" do
    mine = create_mine(tier: 2, specialization: "iron")

    assert_equal 0.90, mine.price_modifier_for("iron")
  end

  test "tier 3 mine reduces price of its mineral by 15%" do
    mine = create_mine(tier: 3, specialization: "iron")

    assert_equal 0.85, mine.price_modifier_for("iron")
  end

  test "tier 4 mine reduces price of its mineral by 20%" do
    mine = create_mine(tier: 4, specialization: "iron")

    assert_equal 0.80, mine.price_modifier_for("iron")
  end

  test "tier 5 mine reduces price of its mineral by 25%" do
    mine = create_mine(tier: 5, specialization: "iron")

    assert_equal 0.75, mine.price_modifier_for("iron")
  end

  test "mine does not reduce price of other commodities" do
    mine = create_mine(tier: 3, specialization: "iron")

    assert_equal 1.0, mine.price_modifier_for("copper")
    assert_equal 1.0, mine.price_modifier_for("fuel")
    assert_equal 1.0, mine.price_modifier_for("electronics")
  end

  test "disabled mine does not reduce prices" do
    mine = create_mine(tier: 3, specialization: "iron")
    mine.update!(disabled_at: Time.current)

    assert_equal 1.0, mine.price_modifier_for("iron")
  end

  test "non-extraction buildings return 1.0" do
    warehouse = Building.new(
      user: @user,
      system: @system,
      name: "Logistics Hub",
      function: "logistics",
      race: "vex",
      tier: 3,
      status: "active",
      uuid: Building.generate_uuid7,
      short_id: "bl-log-test"
    )
    warehouse.save(validate: false) # Skip one_warehouse validation

    assert_equal 1.0, warehouse.price_modifier_for("iron")
  end

  private

  def create_mine(tier:, specialization:)
    Building.create!(
      user: @user,
      system: @system,
      name: "#{specialization.capitalize} Mine T#{tier}",
      function: "extraction",
      race: "vex",
      tier: tier,
      status: "active",
      specialization: specialization,
      uuid: Building.generate_uuid7
    )
  end
end
