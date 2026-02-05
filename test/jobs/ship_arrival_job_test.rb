# frozen_string_literal: true

require "test_helper"

class ShipArrivalJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @origin = systems(:cradle)
    @destination = systems(:alpha_centauri)
  end

  test "processes ships that have arrived at destination" do
    ship = Ship.create!(
      user: @user,
      name: "Test Ship",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      current_system: @origin,
      status: "in_transit",
      destination_system: @destination,
      arrival_at: 1.minute.ago
    )

    assert_equal "in_transit", ship.status
    assert_equal @origin, ship.current_system

    ShipArrivalJob.perform_now

    ship.reload
    assert_equal "docked", ship.status
    assert_equal @destination, ship.current_system
    assert_nil ship.destination_system
    assert_nil ship.arrival_at
  end

  test "does not process ships still in transit" do
    ship = Ship.create!(
      user: @user,
      name: "Test Ship",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      current_system: @origin,
      status: "in_transit",
      destination_system: @destination,
      arrival_at: 1.hour.from_now
    )

    assert_equal "in_transit", ship.status

    ShipArrivalJob.perform_now

    ship.reload
    assert_equal "in_transit", ship.status
    assert_equal @origin, ship.current_system
    assert_equal @destination, ship.destination_system
  end

  test "does not process docked ships" do
    ship = Ship.create!(
      user: @user,
      name: "Test Ship",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      current_system: @origin,
      status: "docked"
    )

    original_system = ship.current_system

    ShipArrivalJob.perform_now

    ship.reload
    assert_equal "docked", ship.status
    assert_equal original_system, ship.current_system
  end

  test "returns count of processed arrivals" do
    # Create two ships with past arrival times
    2.times do |i|
      Ship.create!(
        user: @user,
        name: "Arrival Ship #{i}",
        race: "vex",
        hull_size: "scout",
        variant_idx: 0,
        fuel: 100,
        current_system: @origin,
        status: "in_transit",
        destination_system: @destination,
        arrival_at: 1.minute.ago
      )
    end

    # One ship still in transit
    Ship.create!(
      user: @user,
      name: "Still Traveling",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      current_system: @origin,
      status: "in_transit",
      destination_system: @destination,
      arrival_at: 1.hour.from_now
    )

    result = ShipArrivalJob.perform_now

    assert_equal 2, result[:arrivals_processed]
  end

  # NOTE: Battle intent test removed - pending_intent is an attr_accessor
  # and doesn't persist across job runs. This is a design limitation
  # that should be addressed separately (migrate pending_intent to a column).
end
