require "test_helper"

class BuildingValidationTest < ActiveSupport::TestCase
  def setup
    @user = users(:pilot)

    # Create a fresh system with minerals for testing
    # Coordinates must be divisible by 3 and in range 0-9
    @system = System.new(
      name: "Test System",
      short_id: "sy-test-#{SecureRandom.hex(4)}",
      x: 6,
      y: 6,
      z: 6
    )
    # Set properties after initialization to override procedural generation
    @system.properties = {
      star_type: "yellow_dwarf",
      planet_count: 3,
      hazard_level: 0,
      mineral_distribution: {
        "0" => { "minerals" => %w[iron copper], "abundance" => "common" },
        "1" => { "minerals" => %w[gold titanium], "abundance" => "rare" }
      }
    }
    @system.save!
  end

  # =========================================
  # MINE VALIDATIONS (function: extraction)
  # =========================================

  test "mine must have specialization matching system minerals" do
    mine = Building.new(
      user: @user,
      system: @system,
      name: "Iron Mine",
      function: "extraction",
      specialization: "iron",
      race: "vex",
      tier: 1
    )
    assert mine.valid?, "Mine with valid mineral should be valid"
  end

  test "mine cannot have specialization for mineral not in system" do
    mine = Building.new(
      user: @user,
      system: @system,
      name: "Platinum Mine",
      function: "extraction",
      specialization: "platinum",  # Not in system minerals
      race: "vex",
      tier: 1
    )
    assert_not mine.valid?, "Mine with invalid mineral should be invalid"
    assert_includes mine.errors[:specialization], "must match a mineral available in this system"
  end

  test "mine requires specialization" do
    mine = Building.new(
      user: @user,
      system: @system,
      name: "Generic Mine",
      function: "extraction",
      specialization: nil,
      race: "vex",
      tier: 1
    )
    assert_not mine.valid?, "Mine without specialization should be invalid"
    assert_includes mine.errors[:specialization], "is required for extraction buildings"
  end

  test "only one mine per mineral type per system" do
    # Create first iron mine
    Building.create!(
      user: @user,
      system: @system,
      name: "Iron Mine Alpha",
      function: "extraction",
      specialization: "iron",
      race: "vex",
      tier: 1
    )

    # Try to create second iron mine - should fail
    second_mine = Building.new(
      user: @user,
      system: @system,
      name: "Iron Mine Beta",
      function: "extraction",
      specialization: "iron",
      race: "vex",
      tier: 1
    )
    assert_not second_mine.valid?, "Second iron mine in same system should be invalid"
    assert_includes second_mine.errors[:specialization], "already has a mine for this mineral in this system"
  end

  test "can have different mineral mines in same system" do
    # Create iron mine
    Building.create!(
      user: @user,
      system: @system,
      name: "Iron Mine",
      function: "extraction",
      specialization: "iron",
      race: "vex",
      tier: 1
    )

    # Create copper mine - should work
    copper_mine = Building.new(
      user: @user,
      system: @system,
      name: "Copper Mine",
      function: "extraction",
      specialization: "copper",
      race: "vex",
      tier: 1
    )
    assert copper_mine.valid?, "Different mineral mine should be valid"
  end

  # =========================================
  # WAREHOUSE VALIDATIONS (function: logistics)
  # =========================================

  test "only one warehouse per system" do
    Building.create!(
      user: @user,
      system: @system,
      name: "Main Warehouse",
      function: "logistics",
      race: "vex",
      tier: 1
    )

    second_warehouse = Building.new(
      user: @user,
      system: @system,
      name: "Second Warehouse",
      function: "logistics",
      race: "vex",
      tier: 1
    )
    assert_not second_warehouse.valid?, "Second warehouse in same system should be invalid"
    assert_includes second_warehouse.errors[:function], "only one logistics building allowed per system"
  end

  test "can upgrade existing warehouse instead of building new one" do
    warehouse = Building.create!(
      user: @user,
      system: @system,
      name: "Main Warehouse",
      function: "logistics",
      race: "vex",
      tier: 1
    )

    # Upgrading same building should work
    warehouse.tier = 2
    assert warehouse.valid?, "Upgrading existing warehouse should be valid"
  end

  test "different systems can each have a warehouse" do
    Building.create!(
      user: @user,
      system: @system,
      name: "Cradle Warehouse",
      function: "logistics",
      race: "vex",
      tier: 1
    )

    other_system = System.create!(
      name: "Other System",
      short_id: "sy-other-#{SecureRandom.hex(4)}",
      x: 3,
      y: 3,
      z: 3
    )
    other_warehouse = Building.new(
      user: @user,
      system: other_system,
      name: "Alpha Warehouse",
      function: "logistics",
      race: "vex",
      tier: 1
    )
    assert other_warehouse.valid?, "Warehouse in different system should be valid"
  end

  # =========================================
  # MARKETPLACE VALIDATIONS (function: civic)
  # =========================================

  test "only one marketplace per system" do
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market",
      function: "civic",
      race: "vex",
      tier: 1
    )

    second_marketplace = Building.new(
      user: @user,
      system: @system,
      name: "Second Market",
      function: "civic",
      race: "vex",
      tier: 1
    )
    assert_not second_marketplace.valid?, "Second marketplace in same system should be invalid"
    assert_includes second_marketplace.errors[:function], "only one civic building allowed per system"
  end

  test "can upgrade existing marketplace" do
    marketplace = Building.create!(
      user: @user,
      system: @system,
      name: "Central Market",
      function: "civic",
      race: "vex",
      tier: 1
    )

    marketplace.tier = 2
    assert marketplace.valid?, "Upgrading existing marketplace should be valid"
  end

  # =========================================
  # FACTORY VALIDATIONS (function: refining)
  # =========================================

  test "factory requires marketplace to exist first" do
    # No marketplace exists
    factory = Building.new(
      user: @user,
      system: @system,
      name: "Basic Factory",
      function: "refining",
      specialization: "basic",
      race: "vex",
      tier: 1
    )
    assert_not factory.valid?, "Factory without marketplace should be invalid"
    assert_includes factory.errors[:base], "requires a marketplace (civic building) in the system"
  end

  test "factory valid when marketplace exists" do
    # Create marketplace first
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market",
      function: "civic",
      race: "vex",
      tier: 1
    )

    factory = Building.new(
      user: @user,
      system: @system,
      name: "Basic Factory",
      function: "refining",
      specialization: "basic",
      race: "vex",
      tier: 1
    )
    assert factory.valid?, "Factory with marketplace should be valid"
  end

  test "multiple factories allowed with different specializations" do
    # Create marketplace first
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market",
      function: "civic",
      race: "vex",
      tier: 1
    )

    # Create first factory
    Building.create!(
      user: @user,
      system: @system,
      name: "Basic Factory",
      function: "refining",
      specialization: "basic",
      race: "vex",
      tier: 1
    )

    # Create second factory with different specialization
    alloy_factory = Building.new(
      user: @user,
      system: @system,
      name: "Electronics Factory",
      function: "refining",
      specialization: "electronics",
      race: "vex",
      tier: 1
    )
    assert alloy_factory.valid?, "Factory with different specialization should be valid"
  end

  test "cannot have duplicate factory specializations in same system" do
    # Create marketplace first
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market",
      function: "civic",
      race: "vex",
      tier: 1
    )

    # Create first steel factory
    Building.create!(
      user: @user,
      system: @system,
      name: "Basic Factory Alpha",
      function: "refining",
      specialization: "basic",
      race: "vex",
      tier: 1
    )

    # Try to create second steel factory - should fail
    second_steel = Building.new(
      user: @user,
      system: @system,
      name: "Basic Factory Beta",
      function: "refining",
      specialization: "basic",
      race: "vex",
      tier: 1
    )
    assert_not second_steel.valid?, "Duplicate factory specialization should be invalid"
    assert_includes second_steel.errors[:specialization], "already has a factory with this specialization in this system"
  end

  test "factory requires specialization" do
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market",
      function: "civic",
      race: "vex",
      tier: 1
    )

    factory = Building.new(
      user: @user,
      system: @system,
      name: "Generic Factory",
      function: "refining",
      specialization: nil,
      race: "vex",
      tier: 1
    )
    assert_not factory.valid?, "Factory without specialization should be invalid"
    assert_includes factory.errors[:specialization], "is required for refining buildings"
  end
end
