require "test_helper"

class WarpRouteServiceTest < ActiveSupport::TestCase
  setup do
    @sys_a = systems(:cradle)
    @sys_b = systems(:mira_station)
    @sys_c = systems(:verdant_gardens)
    @sys_d = systems(:nexus_hub)
    @disconnected = systems(:alpha_centauri)
  end

  test "returns nil for same system" do
    assert_nil WarpRouteService.find_route(@sys_a, @sys_a)
  end

  test "finds direct connection (1 hop)" do
    WarpGate.create!(system_a: @sys_a, system_b: @sys_b, short_id: "wg-ab1")
    route = WarpRouteService.find_route(@sys_a, @sys_b)

    assert_not_nil route
    assert_equal 1, route[:hops]
    assert_equal [@sys_a, @sys_b], route[:path]
    assert_equal WarpGate::WARP_FUEL_COST, route[:fuel_cost]
  end

  test "finds multi-hop route" do
    WarpGate.create!(system_a: @sys_a, system_b: @sys_b, short_id: "wg-ab2")
    WarpGate.create!(system_a: @sys_b, system_b: @sys_c, short_id: "wg-bc2")

    route = WarpRouteService.find_route(@sys_a, @sys_c)
    assert_not_nil route
    assert_equal 2, route[:hops]
    assert_equal [@sys_a, @sys_b, @sys_c], route[:path]
    assert_equal 2 * WarpGate::WARP_FUEL_COST, route[:fuel_cost]
  end

  test "returns nil when no route exists" do
    # No gates created
    route = WarpRouteService.find_route(@sys_a, @disconnected)
    assert_nil route
  end

  test "finds shortest path when multiple routes exist" do
    # Direct: A -> D (1 hop)
    WarpGate.create!(system_a: @sys_a, system_b: @sys_d, short_id: "wg-ad3")
    # Indirect: A -> B -> C -> D (3 hops)
    WarpGate.create!(system_a: @sys_a, system_b: @sys_b, short_id: "wg-ab3")
    WarpGate.create!(system_a: @sys_b, system_b: @sys_c, short_id: "wg-bc3")
    WarpGate.create!(system_a: @sys_c, system_b: @sys_d, short_id: "wg-cd3")

    route = WarpRouteService.find_route(@sys_a, @sys_d)
    assert_equal 1, route[:hops]
  end

  test "ignores offline gates" do
    WarpGate.create!(system_a: @sys_a, system_b: @sys_b, short_id: "wg-ab4", status: "offline")
    route = WarpRouteService.find_route(@sys_a, @sys_b)
    assert_nil route
  end

  test "route through three systems" do
    WarpGate.create!(system_a: @sys_a, system_b: @sys_b, short_id: "wg-ab5")
    WarpGate.create!(system_a: @sys_b, system_b: @sys_c, short_id: "wg-bc5")
    WarpGate.create!(system_a: @sys_c, system_b: @sys_d, short_id: "wg-cd5")

    route = WarpRouteService.find_route(@sys_a, @sys_d)
    assert_not_nil route
    assert_equal 3, route[:hops]
    assert_equal 3 * WarpGate::WARP_FUEL_COST, route[:fuel_cost]
  end
end
