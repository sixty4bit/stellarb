require "test_helper"

class ShipTravelCoordinatesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @system = systems(:cradle)
    @ship = ships(:hauler)
    @ship.update_columns(
      current_system_id: @system.id,
      location_x: @system.x,
      location_y: @system.y,
      location_z: @system.z,
      fuel: 100.0,
      status: "docked"
    )
  end

  test "travel_to_coordinates sets ship in transit" do
    result = @ship.travel_to_coordinates!(510, 500, 500, intent: :explore)
    assert result.success?
    @ship.reload
    assert_equal "in_transit", @ship.status
    assert_not_nil @ship.arrival_at
  end

  test "travel_to_coordinates deducts fuel based on distance" do
    initial_fuel = @ship.fuel
    @ship.travel_to_coordinates!(510, 500, 500, intent: :explore)
    @ship.reload
    assert @ship.fuel < initial_fuel
  end

  test "travel_to_coordinates rejects when insufficient fuel" do
    @ship.update_columns(fuel: 0.1)
    result = @ship.travel_to_coordinates!(999, 999, 999, intent: :explore)
    assert_not result.success?
    assert_match /fuel/i, result.error
  end

  test "travel_to_coordinates rejects when already in transit" do
    @ship.update_columns(status: "in_transit")
    result = @ship.travel_to_coordinates!(510, 500, 500, intent: :explore)
    assert_not result.success?
    assert_match /already in transit/i, result.error
  end

  test "travel_to_coordinates stores destination coordinates" do
    @ship.travel_to_coordinates!(510, 505, 502, intent: :explore)
    @ship.reload
    assert_equal 510, @ship.destination_x
    assert_equal 505, @ship.destination_y
    assert_equal 502, @ship.destination_z
  end

  test "check_arrival for coordinate travel with no system" do
    @ship.travel_to_coordinates!(510, 500, 500, intent: :explore)
    @ship.reload
    @ship.update_columns(arrival_at: 1.minute.ago)

    @ship.check_arrival!
    @ship.reload

    assert_equal "docked", @ship.status
    assert_equal 510, @ship.location_x
    assert_equal 500, @ship.location_y
    assert_equal 500, @ship.location_z
    assert_nil @ship.current_system_id
    assert_nil @ship.arrival_at
  end
end
