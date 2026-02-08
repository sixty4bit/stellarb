require "test_helper"

class ShipWarpRouteTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot) # hauler belongs to pilot
    @sys_a = systems(:cradle)
    @sys_b = systems(:mira_station)
    @sys_c = systems(:verdant_gardens)
    @ship = ships(:hauler)
    @ship.update_columns(current_system_id: @sys_a.id, fuel: 100.0, status: "docked",
                         location_x: @sys_a.x, location_y: @sys_a.y, location_z: @sys_a.z)

    WarpGate.create!(system_a: @sys_a, system_b: @sys_b, short_id: "wg-wr1")
    WarpGate.create!(system_a: @sys_b, system_b: @sys_c, short_id: "wg-wr2")
  end

  teardown do
    WarpGate.where(short_id: %w[wg-wr1 wg-wr2]).delete_all
  end

  test "warp_route! executes multi-hop route" do
    route = WarpRouteService.find_route(@sys_a, @sys_c)
    result = @ship.warp_route!(route)
    assert result.success?
    @ship.reload
    assert_equal @sys_c.id, @ship.current_system_id
    assert_equal "docked", @ship.status
  end

  test "warp_route! deducts correct fuel" do
    route = WarpRouteService.find_route(@sys_a, @sys_c)
    initial_fuel = @ship.fuel
    @ship.warp_route!(route)
    @ship.reload
    expected_fuel = initial_fuel - route[:fuel_cost]
    assert_in_delta expected_fuel, @ship.fuel, 0.01
  end

  test "warp_route! records system visits at intermediates" do
    route = WarpRouteService.find_route(@sys_a, @sys_c)
    @ship.warp_route!(route)

    assert SystemVisit.exists?(user: @user, system: @sys_b), "Should record visit at intermediate"
    assert SystemVisit.exists?(user: @user, system: @sys_c), "Should record visit at destination"
  end

  test "warp_route! rejects insufficient fuel" do
    @ship.update_columns(fuel: 0.1)
    route = WarpRouteService.find_route(@sys_a, @sys_c)
    result = @ship.warp_route!(route)
    assert_not result.success?
    assert_match /fuel/i, result.error
  end

  test "warp_route! rejects when in transit" do
    @ship.update_columns(status: "in_transit")
    route = WarpRouteService.find_route(@sys_a, @sys_c)
    result = @ship.warp_route!(route)
    assert_not result.success?
  end
end
