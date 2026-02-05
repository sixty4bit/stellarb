# frozen_string_literal: true

require "test_helper"

class ShipArrivalsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
    @ship = ships(:hauler)
  end

  test "ships index automatically checks arrivals for in_transit ships" do
    # Put ship in transit with arrival time in the past
    destination = systems(:alpha_centauri)
    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    # Access ships index
    get ships_path
    assert_response :success

    # Ship should now be docked at destination
    @ship.reload
    assert_equal "docked", @ship.status
    assert_equal destination.id, @ship.current_system_id
    assert_nil @ship.destination_system_id
    assert_nil @ship.arrival_at
  end

  test "ships show automatically checks arrivals" do
    destination = systems(:alpha_centauri)
    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    get ship_path(@ship)
    assert_response :success

    @ship.reload
    assert_equal "docked", @ship.status
    assert_equal destination.id, @ship.current_system_id
  end

  test "navigation index automatically checks arrivals" do
    destination = systems(:alpha_centauri)
    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    get navigation_index_path
    assert_response :success

    @ship.reload
    assert_equal "docked", @ship.status
    assert_equal destination.id, @ship.current_system_id
  end

  test "does not change ships that have not arrived yet" do
    destination = systems(:alpha_centauri)
    original_system = @ship.current_system
    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.hour.from_now,
      pending_intent: "trade"
    )

    get ships_path
    assert_response :success

    # Ship should still be in transit
    @ship.reload
    assert_equal "in_transit", @ship.status
    assert_equal original_system.id, @ship.current_system_id
    assert_equal destination.id, @ship.destination_system_id
  end

  test "does not change already docked ships" do
    assert_equal "docked", @ship.status
    original_system = @ship.current_system

    get ships_path
    assert_response :success

    @ship.reload
    assert_equal "docked", @ship.status
    assert_equal original_system.id, @ship.current_system_id
  end

  # Arrival notification tests (4s1.5)
  test "arrival creates inbox notification message" do
    destination = systems(:alpha_centauri)
    # Create a prior visit so this isn't a first visit
    SystemVisit.record_visit(@user, destination)

    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    assert_difference "Message.count", 1 do
      @ship.check_arrival!
    end

    message = Message.last
    assert_equal @user, message.user
    assert_equal "Arrival at #{destination.name}", message.title
    assert_includes message.body, @ship.name
    assert_equal "Navigation System", message.from
    assert_equal "travel", message.category
  end

  # First visit notification tests (4s1.8)
  test "first visit creates discovery notification" do
    destination = systems(:alpha_centauri)
    # Ensure no prior visits
    SystemVisit.where(user: @user, system: destination).destroy_all

    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    # Should create 2 messages: arrival + discovery
    assert_difference "Message.count", 2 do
      @ship.check_arrival!
    end

    discovery_message = Message.where(user: @user, category: "discovery").last
    assert_equal "🌟 New System Discovered: #{destination.name}", discovery_message.title
    assert_includes discovery_message.body, "first to visit"
    assert_equal "Exploration Bureau", discovery_message.from
  end

  test "subsequent visits do not create discovery notification" do
    destination = systems(:alpha_centauri)
    # Create a prior visit
    SystemVisit.record_visit(@user, destination)

    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    # Should create only 1 message: arrival (no discovery)
    assert_difference "Message.count", 1 do
      @ship.check_arrival!
    end

    # The message should be arrival, not discovery
    message = Message.last
    assert_equal "travel", message.category
    assert_not_equal "discovery", message.category
  end
end
