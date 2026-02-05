require "test_helper"

class WarpGateTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Test User", email: "user@test.com")
    @system_a = System.create!(x: 0, y: 0, z: 0, name: "Hub Alpha")
    @system_b = System.create!(x: 3, y: 3, z: 3, name: "Hub Beta")
    @system_c = System.create!(x: 6, y: 0, z: 0, name: "Hub Gamma")
    @remote = System.create!(x: 9, y: 9, z: 9, name: "Remote Outpost")
  end

  # Warp Gate creation tests
  test "creates a bidirectional warp gate between systems" do
    gate = WarpGate.create!(
      system_a: @system_a,
      system_b: @system_b,
      name: "Alpha-Beta Gate"
    )

    assert gate.persisted?
    assert_equal @system_a, gate.system_a
    assert_equal @system_b, gate.system_b
  end

  test "warp gate requires both systems" do
    gate = WarpGate.new(system_a: @system_a, name: "Broken Gate")
    refute gate.valid?
    assert_includes gate.errors[:system_b], "must exist"
  end

  test "cannot create duplicate warp gate between same systems" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b, name: "Gate 1")

    duplicate = WarpGate.new(system_a: @system_a, system_b: @system_b, name: "Gate 2")
    refute duplicate.valid?
  end

  test "reverse direction is also blocked as duplicate" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b, name: "Gate 1")

    # Same gate, reversed direction
    reversed = WarpGate.new(system_a: @system_b, system_b: @system_a, name: "Gate 2")
    refute reversed.valid?
  end

  # Connected systems tests
  test "finds systems connected by warp gates" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)
    WarpGate.create!(system_a: @system_a, system_b: @system_c)

    connected = @system_a.warp_connected_systems
    assert_includes connected, @system_b
    assert_includes connected, @system_c
    refute_includes connected, @remote
  end

  test "connection works bidirectionally" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)

    # A can reach B
    assert_includes @system_a.warp_connected_systems, @system_b
    # B can reach A (bidirectional)
    assert_includes @system_b.warp_connected_systems, @system_a
  end

  # Warp travel tests
  test "ship can warp to connected system" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)

    ship = Ship.create!(
      name: "Warper",
      user: @user,
      race: "solari",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 50.0,
      current_system: @system_a,
      status: "docked"
    )

    result = ship.warp_to!(@system_b)

    assert result.success?
    assert_equal "docked", ship.status  # Instant travel
    assert_equal @system_b, ship.current_system
  end

  test "warp travel uses less fuel than normal travel" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)

    ship = Ship.create!(
      name: "Warper",
      user: @user,
      race: "solari",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100.0,
      current_system: @system_a,
      status: "docked"
    )

    normal_fuel = ship.fuel_required_for(@system_b)
    warp_fuel = ship.warp_fuel_required_for(@system_b)

    # Warp should be cheaper (flat rate or reduced)
    assert warp_fuel < normal_fuel
  end

  test "cannot warp to unconnected system" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)

    ship = Ship.create!(
      name: "Warper",
      user: @user,
      race: "solari",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100.0,
      current_system: @system_a,
      status: "docked"
    )

    result = ship.warp_to!(@remote)  # No warp gate to remote

    refute result.success?
    assert_includes result.error, "warp gate"
    assert_equal @system_a, ship.current_system  # Didn't move
  end

  test "cannot warp while in transit" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)

    ship = Ship.create!(
      name: "Warper",
      user: @user,
      race: "solari",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100.0,
      current_system: @system_a,
      status: "in_transit"
    )

    result = ship.warp_to!(@system_b)

    refute result.success?
    assert_includes result.error, "transit"
  end

  # Warp gate status tests
  test "warp gate can be disabled" do
    gate = WarpGate.create!(
      system_a: @system_a,
      system_b: @system_b,
      status: "offline"
    )

    ship = Ship.create!(
      name: "Warper",
      user: @user,
      race: "solari",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100.0,
      current_system: @system_a,
      status: "docked"
    )

    result = ship.warp_to!(@system_b)

    refute result.success?
    assert_includes result.error, "offline"
  end

  test "finds warp gate between two systems" do
    gate = WarpGate.create!(system_a: @system_a, system_b: @system_b)

    found = WarpGate.between(@system_a, @system_b)
    assert_equal gate, found

    # Works in reverse too
    found_reverse = WarpGate.between(@system_b, @system_a)
    assert_equal gate, found_reverse
  end
end
