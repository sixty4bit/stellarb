require "test_helper"

class ShipTravelTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Test Captain", email: "captain@test.com")
    @origin = System.create!(x: 0, y: 0, z: 0, name: "Origin")
    @destination = System.create!(x: 3, y: 4, z: 0, name: "Destination")  # Distance = 5

    @ship = Ship.create!(
      name: "Test Ship",
      user: @user,
      race: "vex",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100.0,
      current_system: @origin,
      status: "docked"
    )
  end

  # Distance calculation tests
  test "calculates distance between two systems" do
    # 3D Euclidean distance: sqrt(3^2 + 4^2 + 0^2) = 5
    assert_equal 5.0, System.distance_between(@origin, @destination)
  end

  test "calculates distance to distant system" do
    distant = System.create!(x: 100, y: 100, z: 100, name: "Distant")
    # sqrt(100^2 + 100^2 + 100^2) = sqrt(30000) ≈ 173.2
    distance = System.distance_between(@origin, distant)
    assert_in_delta 173.2, distance, 0.1
  end

  # Fuel consumption tests
  test "calculates fuel required for journey" do
    # Base fuel cost is 1 fuel per distance unit, modified by fuel_efficiency
    fuel_needed = @ship.fuel_required_for(@destination)
    # Distance is 5, efficiency is 1.0 for vex, so 5 fuel
    assert_equal 5.0, fuel_needed
  end

  test "fuel consumption considers ship efficiency" do
    @ship.ship_attributes["fuel_efficiency"] = 0.5  # More efficient
    fuel_needed = @ship.fuel_required_for(@destination)
    assert_equal 2.5, fuel_needed
  end

  test "checks if ship can reach destination" do
    assert @ship.can_reach?(@destination)

    @ship.fuel = 2.0  # Not enough fuel
    refute @ship.can_reach?(@destination)
  end

  # Travel time/ETA tests
  test "calculates travel time based on distance" do
    # Base speed: 1 unit per game tick (configurable)
    # For distance 5 with speed 1.0 = 5 ticks
    travel_time = @ship.travel_time_to(@destination)
    assert_equal 5, travel_time
  end

  test "travel time considers ship maneuverability" do
    # Higher maneuverability = faster travel
    @ship.ship_attributes["maneuverability"] = 100  # Double speed
    travel_time = @ship.travel_time_to(@destination)
    # Distance 5, speed multiplier 2x = 2.5 ticks, ceiling = 3
    assert_equal 3, travel_time  # Faster due to higher maneuverability (5 -> 3)
  end

  # Initiate travel tests
  test "ship can initiate travel to destination" do
    result = @ship.travel_to!(@destination)

    assert result.success?
    assert_equal "in_transit", @ship.status
    assert_equal @destination.id, @ship.destination_system_id
    assert_not_nil @ship.arrival_at
    assert_equal 95.0, @ship.fuel  # 100 - 5
  end

  test "ship cannot travel without sufficient fuel" do
    @ship.update!(fuel: 2.0)

    result = @ship.travel_to!(@destination)

    refute result.success?
    assert_equal "docked", @ship.status
    assert_includes result.error, "fuel"
  end

  test "ship cannot travel while already in transit" do
    @ship.update!(status: "in_transit")

    result = @ship.travel_to!(@destination)

    refute result.success?
    assert_includes result.error, "transit"
  end

  test "ship cannot travel to current system" do
    result = @ship.travel_to!(@origin)

    refute result.success?
    assert_includes result.error, "already"
  end

  # Arrival tests
  test "ship arrives at destination when arrival time reached" do
    @ship.travel_to!(@destination)
    @ship.update!(arrival_at: 1.minute.ago)

    @ship.check_arrival!

    assert_equal "docked", @ship.status
    assert_equal @destination.id, @ship.current_system_id
    assert_nil @ship.destination_system_id
    assert_nil @ship.arrival_at
  end

  test "ship does not arrive before arrival time" do
    @ship.travel_to!(@destination)
    @ship.update!(arrival_at: 1.minute.from_now)

    @ship.check_arrival!

    assert_equal "in_transit", @ship.status
    assert_equal @origin.id, @ship.current_system_id
  end
end
