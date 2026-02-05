# frozen_string_literal: true

require "test_helper"

class ShipArrivalNotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @origin = systems(:cradle)
    @destination = systems(:alpha_centauri)

    @ship = Ship.create!(
      name: "Notification Test Ship",
      user: @user,
      race: "vex",
      hull_size: "scout",
      variant_idx: 1,
      fuel: 50,
      status: "in_transit",
      current_system: nil,
      location_x: @origin.x,
      location_y: @origin.y,
      location_z: @origin.z,
      destination_system: @destination,
      arrival_at: 1.minute.ago  # Already arrived
    )
  end

  test "check_arrival! creates inbox message on arrival" do
    assert_difference -> { @user.messages.count }, 1 do
      @ship.check_arrival!
    end
  end

  test "arrival message has correct title" do
    @ship.check_arrival!

    message = @user.messages.last
    assert_includes message.title, @destination.name
    assert_match /arrival/i, message.title
  end

  test "arrival message has correct body" do
    @ship.check_arrival!

    message = @user.messages.last
    assert_includes message.body, @ship.name
    assert_includes message.body, @destination.name
  end

  test "arrival message has correct sender" do
    @ship.check_arrival!

    message = @user.messages.last
    assert_equal "Navigation System", message.from
  end

  test "arrival message has travel category" do
    @ship.check_arrival!

    message = @user.messages.last
    assert_equal "travel", message.category
  end

  test "arrival message belongs to ship owner" do
    @ship.check_arrival!

    message = @user.messages.last
    assert_equal @user.id, message.user_id
  end

  test "no message if ship not in transit" do
    @ship.update!(status: "docked", destination_system: nil, arrival_at: nil, current_system: @origin)

    assert_no_difference -> { @user.messages.count } do
      @ship.check_arrival!
    end
  end

  test "no message if arrival time not reached" do
    @ship.update!(arrival_at: 1.hour.from_now)

    assert_no_difference -> { @user.messages.count } do
      @ship.check_arrival!
    end
  end
end
