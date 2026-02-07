# frozen_string_literal: true

require "test_helper"

class FlightRecordTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Pilot", email: "pilot@test.com")
    @origin = System.find_or_create_by!(x: 0, y: 0, z: 0) { |s| s.name = "Origin" }
    @destination = System.create!(x: 3, y: 0, z: 0, name: "Destination")
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

  # ===========================================
  # Record Creation Tests
  # ===========================================

  test "record_departure creates a departure record" do
    record = FlightRecord.record_departure(@ship, @origin, @destination)

    assert record.persisted?
    assert_equal "departure", record.event_type
    assert_equal @ship, record.ship
    assert_equal @user, record.user
    assert_equal @origin, record.from_system
    assert_equal @destination, record.to_system
    assert record.occurred_at.present?
  end

  test "record_arrival creates an arrival record" do
    record = FlightRecord.record_arrival(@ship, @origin, @destination)

    assert record.persisted?
    assert_equal "arrival", record.event_type
    assert_equal @ship, record.ship
    assert_equal @user, record.user
    assert_equal @origin, record.from_system
    assert_equal @destination, record.to_system
    assert record.occurred_at.present?
  end

  test "record includes distance traveled" do
    record = FlightRecord.record_departure(@ship, @origin, @destination)

    assert_equal System.distance_between(@origin, @destination), record.distance
  end

  # ===========================================
  # Query Tests
  # ===========================================

  test "user can retrieve their flight history" do
    FlightRecord.record_departure(@ship, @origin, @destination)
    FlightRecord.record_arrival(@ship, @origin, @destination)

    history = @user.flight_history
    assert_equal 2, history.count
  end

  test "flight history is ordered by most recent first" do
    travel_to 2.days.ago do
      FlightRecord.record_departure(@ship, @origin, @destination)
    end

    travel_to 1.day.ago do
      FlightRecord.record_arrival(@ship, @origin, @destination)
    end

    history = @user.flight_history
    # Most recent first
    assert_equal "arrival", history.first.event_type
    assert_equal "departure", history.last.event_type
  end

  test "ship has flight history" do
    FlightRecord.record_departure(@ship, @origin, @destination)

    assert_equal 1, @ship.flight_records.count
  end

  test "system has departures and arrivals" do
    FlightRecord.record_departure(@ship, @origin, @destination)
    FlightRecord.record_arrival(@ship, @origin, @destination)

    assert_equal 1, @origin.departures.count
    assert_equal 1, @destination.arrivals.count
  end

  # ===========================================
  # Validation Tests
  # ===========================================

  test "requires ship" do
    record = FlightRecord.new(
      user: @user,
      from_system: @origin,
      to_system: @destination,
      event_type: "departure",
      occurred_at: Time.current
    )

    assert_not record.valid?
    assert_includes record.errors[:ship], "must exist"
  end

  test "requires user" do
    record = FlightRecord.new(
      ship: @ship,
      from_system: @origin,
      to_system: @destination,
      event_type: "departure",
      occurred_at: Time.current
    )

    assert_not record.valid?
    assert_includes record.errors[:user], "must exist"
  end

  test "requires event_type" do
    record = FlightRecord.new(
      ship: @ship,
      user: @user,
      from_system: @origin,
      to_system: @destination,
      occurred_at: Time.current
    )

    assert_not record.valid?
    assert_includes record.errors[:event_type], "can't be blank"
  end

  test "event_type must be departure or arrival" do
    record = FlightRecord.new(
      ship: @ship,
      user: @user,
      from_system: @origin,
      to_system: @destination,
      event_type: "explosion",
      occurred_at: Time.current
    )

    assert_not record.valid?
    assert_includes record.errors[:event_type], "is not included in the list"
  end

  # ===========================================
  # Statistics Tests
  # ===========================================

  test "user can get total distance traveled" do
    # First journey: 3 units
    FlightRecord.record_departure(@ship, @origin, @destination)
    FlightRecord.record_arrival(@ship, @origin, @destination)

    # Return journey: 3 units
    FlightRecord.record_departure(@ship, @destination, @origin)
    FlightRecord.record_arrival(@ship, @destination, @origin)

    # Total: 6 units (each journey has 2 records with same distance)
    assert_equal 12.0, @user.total_distance_traveled
  end
end
