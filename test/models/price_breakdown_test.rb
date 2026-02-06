# frozen_string_literal: true

require "test_helper"

class PriceBreakdownTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @system = System.create!(
      name: "Test Breakdown System",
      short_id: "sy-brk-#{SecureRandom.hex(4)}",
      x: rand(1000),
      y: rand(1000),
      z: rand(1000),
      properties: {
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron", "copper"], "abundance" => "high" },
          "1" => { "minerals" => ["silicon"], "abundance" => "low" }
        },
        "base_prices" => { "iron" => 100, "copper" => 150, "silicon" => 200 }
      }
    )
  end

  test "price_breakdown_for returns a hash with required keys" do
    breakdown = @system.price_breakdown_for("iron")

    assert_instance_of Hash, breakdown
    assert_includes breakdown.keys, :base_price
    assert_includes breakdown.keys, :abundance_modifier
    assert_includes breakdown.keys, :building_effects
    assert_includes breakdown.keys, :delta
    assert_includes breakdown.keys, :final_price
  end

  test "price_breakdown_for shows base price" do
    breakdown = @system.price_breakdown_for("iron")

    assert_equal 100, breakdown[:base_price]
  end

  test "price_breakdown_for shows abundance modifier" do
    # Iron is at "high" abundance, which gives 0.8 modifier
    breakdown = @system.price_breakdown_for("iron")

    assert_equal 0.8, breakdown[:abundance_modifier]
    assert_equal 80, breakdown[:after_abundance] # 100 * 0.8
  end

  test "price_breakdown_for shows each building effect" do
    # Create a T2 mine for iron (-10%)
    Building.create!(
      user: @user,
      system: @system,
      name: "Iron Mine T2",
      function: "extraction",
      race: "vex",
      tier: 2,
      status: "active",
      specialization: "iron",
      uuid: Building.generate_uuid7
    )

    breakdown = @system.price_breakdown_for("iron")

    assert_equal 1, breakdown[:building_effects].length
    effect = breakdown[:building_effects].first
    assert_equal "Iron Mine T2", effect[:building_name]
    assert_equal 0.90, effect[:modifier]
    assert_equal 72, effect[:price_after] # 80 * 0.90
  end

  test "price_breakdown_for shows multiple building effects" do
    # Create a marketplace first (required for factory)
    Building.create!(
      user: @user,
      system: @system,
      name: "Trade Hub",
      function: "civic",
      race: "vex",
      tier: 1,
      status: "active",
      uuid: Building.generate_uuid7
    )

    # Create a T1 mine for iron (-5%)
    Building.create!(
      user: @user,
      system: @system,
      name: "Iron Mine",
      function: "extraction",
      race: "vex",
      tier: 1,
      status: "active",
      specialization: "iron",
      uuid: Building.generate_uuid7
    )

    # Create a factory that increases iron demand (+10% at T1)
    Building.create!(
      user: @user,
      system: @system,
      name: "Basic Factory",
      function: "refining",
      race: "vex",
      tier: 1,
      status: "active",
      specialization: "basic",  # uses iron as input
      uuid: Building.generate_uuid7
    )

    breakdown = @system.price_breakdown_for("iron")

    # Should have 2 building effects (marketplace doesn't affect prices)
    building_effects = breakdown[:building_effects]
    assert_equal 2, building_effects.length

    # Mine reduces price (-5%), factory increases (+10%)
    # Order matters for display: base 100 -> abundance 80 -> mine 76 -> factory 83.6
    mine_effect = building_effects.find { |e| e[:building_name] == "Iron Mine" }
    factory_effect = building_effects.find { |e| e[:building_name] == "Basic Factory" }

    assert_not_nil mine_effect
    assert_not_nil factory_effect
    assert_equal 0.95, mine_effect[:modifier]
    assert_equal 1.10, factory_effect[:modifier]
  end

  test "price_breakdown_for shows delta from price_deltas" do
    # Apply a +20 delta to iron
    PriceDelta.apply_delta(@system, "iron", 20)

    breakdown = @system.price_breakdown_for("iron")

    assert_equal 20, breakdown[:delta]
  end

  test "price_breakdown_for calculates correct final price" do
    # Iron: base 100, abundance 0.8 = 80, no buildings, no delta
    breakdown = @system.price_breakdown_for("iron")

    assert_equal 80, breakdown[:final_price]
  end

  test "price_breakdown_for calculates final price with all modifiers" do
    # Create a T3 mine for iron (-15%)
    Building.create!(
      user: @user,
      system: @system,
      name: "Iron Mine T3",
      function: "extraction",
      race: "vex",
      tier: 3,
      status: "active",
      specialization: "iron",
      uuid: Building.generate_uuid7
    )

    # Apply a +5 delta
    PriceDelta.apply_delta(@system, "iron", 5)

    breakdown = @system.price_breakdown_for("iron")

    # base: 100
    # abundance (0.8): 80
    # mine (-15%): 68
    # delta (+5): 73
    assert_equal 100, breakdown[:base_price]
    assert_equal 0.8, breakdown[:abundance_modifier]
    assert_equal 80, breakdown[:after_abundance]
    assert_equal 1, breakdown[:building_effects].length
    assert_equal 68, breakdown[:building_effects].first[:price_after]
    assert_equal 5, breakdown[:delta]
    assert_equal 73, breakdown[:final_price]
  end

  test "price_breakdown_for returns nil for unknown commodity" do
    breakdown = @system.price_breakdown_for("unobtanium")

    assert_nil breakdown
  end

  test "price_breakdown_for ignores disabled buildings" do
    # Create a disabled mine for iron
    mine = Building.create!(
      user: @user,
      system: @system,
      name: "Disabled Mine",
      function: "extraction",
      race: "vex",
      tier: 3,
      status: "active",
      specialization: "iron",
      uuid: Building.generate_uuid7
    )
    mine.update!(disabled_at: Time.current)

    breakdown = @system.price_breakdown_for("iron")

    assert_equal [], breakdown[:building_effects]
    assert_equal 80, breakdown[:final_price]  # Only abundance applied
  end
end
