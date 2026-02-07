# frozen_string_literal: true

require "test_helper"

class ShipArrivalNotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @origin = systems(:cradle)
    @destination = systems(:alpha_centauri)
  end

  def create_ship_in_transit
    Ship.create!(
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
      arrival_at: 1.minute.ago
    )
  end

  test "no arrival message for repeat visit" do
    # Mark destination as previously visited
    SystemVisit.create!(
      user: @user,
      system: @destination,
      visit_count: 1,
      first_visited_at: 1.day.ago,
      last_visited_at: 1.hour.ago
    )

    ship = create_ship_in_transit

    assert_no_difference -> { @user.messages.where(category: "travel").count } do
      ship.check_arrival!
    end
  end

  test "first visit creates arrival notification" do
    ship = create_ship_in_transit

    ship.check_arrival!

    arrival_msg = @user.messages.find_by(from: "Navigation System", category: "travel")
    assert arrival_msg, "Expected an arrival notification for first visit"
    assert_includes arrival_msg.title, @destination.name
  end

  test "first visit creates discovery notification" do
    ship = create_ship_in_transit

    ship.check_arrival!

    discovery_msg = @user.messages.find_by(from: "Exploration Bureau")
    assert discovery_msg, "Expected a discovery notification for first visit"
    assert_includes discovery_msg.title, @destination.name
  end

  test "first visit creates exactly two messages" do
    ship = create_ship_in_transit

    assert_difference -> { @user.messages.count }, 2 do
      ship.check_arrival!
    end
  end

  test "no message if ship not in transit" do
    ship = create_ship_in_transit
    ship.update!(status: "docked", destination_system: nil, arrival_at: nil, current_system: @origin)

    assert_no_difference -> { @user.messages.count } do
      ship.check_arrival!
    end
  end

  test "no message if arrival time not reached" do
    ship = create_ship_in_transit
    ship.update!(arrival_at: 1.hour.from_now)

    assert_no_difference -> { @user.messages.count } do
      ship.check_arrival!
    end
  end
end
