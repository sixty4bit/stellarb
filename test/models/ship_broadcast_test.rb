# frozen_string_literal: true

require "test_helper"

class ShipBroadcastTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @origin = systems(:cradle)
    @destination = systems(:alpha_centauri)
    @ship = Ship.create!(
      user: @user,
      name: "Test Voyager",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100.0,
      status: "in_transit",
      current_system: nil,
      destination_system: @destination,
      location_x: @origin.x,
      location_y: @origin.y,
      location_z: @origin.z,
      arrival_at: 1.second.ago  # Arrived already
    )
  end

  test "ship has broadcast_arrival method" do
    assert @ship.respond_to?(:broadcast_arrival),
      "Ship should respond to broadcast_arrival"
  end

  test "ship has broadcast_arrival_target method" do
    assert @ship.respond_to?(:broadcast_arrival_target),
      "Ship should respond to broadcast_arrival_target"
  end

  test "broadcast_arrival_target returns correct stream name" do
    expected_target = "ships_user_#{@user.id}"
    assert_equal expected_target, @ship.broadcast_arrival_target
  end

  test "check_arrival! completes successfully and changes status" do
    assert_equal "in_transit", @ship.status
    
    @ship.check_arrival!
    
    assert_equal "docked", @ship.reload.status
    assert_equal @destination, @ship.current_system
    assert_nil @ship.destination_system
  end

  test "broadcast_arrival is called during check_arrival!" do
    # Use a mock to verify broadcast_arrival is called
    broadcast_called = false
    @ship.define_singleton_method(:broadcast_arrival) do
      broadcast_called = true
    end

    @ship.check_arrival!

    assert broadcast_called, "broadcast_arrival should be called during check_arrival!"
  end

  test "no arrival processing when ship is not in transit" do
    docked_ship = Ship.create!(
      user: @user,
      name: "Docked Ship",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100.0,
      status: "docked",
      current_system: @origin
    )

    broadcast_called = false
    docked_ship.define_singleton_method(:broadcast_arrival) do
      broadcast_called = true
    end

    docked_ship.check_arrival!

    refute broadcast_called, "broadcast_arrival should not be called for docked ships"
  end

  test "no arrival processing when arrival time is in the future" do
    future_ship = Ship.create!(
      user: @user,
      name: "Future Ship",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100.0,
      status: "in_transit",
      current_system: nil,
      destination_system: @destination,
      location_x: @origin.x,
      location_y: @origin.y,
      location_z: @origin.z,
      arrival_at: 1.hour.from_now
    )

    broadcast_called = false
    future_ship.define_singleton_method(:broadcast_arrival) do
      broadcast_called = true
    end

    future_ship.check_arrival!

    refute broadcast_called, "broadcast_arrival should not be called when arrival is in the future"
  end

  test "ship includes Turbo::Broadcastable" do
    assert Ship.include?(Turbo::Broadcastable),
      "Ship should include Turbo::Broadcastable"
  end
end
