require "test_helper"

class WarpRouteServiceTest < ActiveSupport::TestCase
  setup do
    @system_a = systems(:cradle)
    @system_b = systems(:mira_station)
    @system_c = systems(:verdant_gardens)
    @system_d = systems(:nexus_hub)
  end

  test "direct connection returns single-hop route" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)

    result = WarpRouteService.find_route(@system_a, @system_b)

    assert_not_nil result
    assert_equal [@system_a, @system_b], result[:path]
    assert_equal 1, result[:hops]
    assert_equal WarpGate::WARP_FUEL_COST, result[:fuel_cost]
  end

  test "multi-hop route through intermediate system" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b)
    WarpGate.create!(system_a: @system_b, system_b: @system_c)

    result = WarpRouteService.find_route(@system_a, @system_c)

    assert_not_nil result
    assert_equal [@system_a, @system_b, @system_c], result[:path]
    assert_equal 2, result[:hops]
    assert_equal 2 * WarpGate::WARP_FUEL_COST, result[:fuel_cost]
  end

  test "returns nil when no route exists" do
    # No gates created — systems are disconnected
    result = WarpRouteService.find_route(@system_a, @system_c)

    assert_nil result
  end

  test "returns trivial route for same source and destination" do
    result = WarpRouteService.find_route(@system_a, @system_a)

    assert_not_nil result
    assert_equal [@system_a], result[:path]
    assert_equal 0, result[:hops]
    assert_equal 0, result[:fuel_cost]
  end

  test "ignores offline gates" do
    WarpGate.create!(system_a: @system_a, system_b: @system_b, status: 'offline')

    result = WarpRouteService.find_route(@system_a, @system_b)

    assert_nil result
  end

  test "finds shortest path when multiple routes exist" do
    # Direct: A -> D (1 hop)
    WarpGate.create!(system_a: @system_a, system_b: @system_d)
    # Longer: A -> B -> C -> D (3 hops)
    WarpGate.create!(system_a: @system_a, system_b: @system_b)
    WarpGate.create!(system_a: @system_b, system_b: @system_c)
    WarpGate.create!(system_a: @system_c, system_b: @system_d)

    result = WarpRouteService.find_route(@system_a, @system_d)

    assert_equal 1, result[:hops]
    assert_equal [@system_a, @system_d], result[:path]
  end
end
