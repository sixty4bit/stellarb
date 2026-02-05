require "test_helper"

class SystemEntryTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Test User", email: "user@test.com")
    @origin = System.create!(x: 0, y: 0, z: 0, name: "Origin")
    @destination = System.create!(x: 3, y: 0, z: 0, name: "Destination")

    @ship = Ship.create!(
      name: "Trader",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100.0,
      current_system: @origin,
      status: "docked"
    )
  end

  # Intent declaration tests
  test "ship can declare trade intent when entering system" do
    @ship.travel_to!(@destination, intent: :trade)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    assert_equal "trade", @ship.system_intent
    assert @ship.trading?
  end

  test "ship can declare battle intent when entering system" do
    @ship.travel_to!(@destination, intent: :battle)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    assert_equal "battle", @ship.system_intent
    assert @ship.hostile?
  end

  test "intent defaults to trade if not specified" do
    @ship.travel_to!(@destination)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    assert_equal "trade", @ship.system_intent
  end

  test "invalid intent is rejected" do
    result = @ship.travel_to!(@destination, intent: :piracy)

    refute result.success?
    assert_includes result.error, "intent"
  end

  # Intent locking tests
  test "intent is locked while ship is in system" do
    @ship.travel_to!(@destination, intent: :trade)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    result = @ship.change_intent!(:battle)

    refute result.success?
    assert_includes result.error, "locked"
    assert_equal "trade", @ship.system_intent
  end

  test "intent clears when ship leaves system" do
    @ship.travel_to!(@destination, intent: :trade)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    # Leave for another system
    third_system = System.create!(x: 6, y: 0, z: 0, name: "Third")
    @ship.travel_to!(third_system)

    assert_nil @ship.system_intent
    refute @ship.trading?
    refute @ship.hostile?
  end

  # Defense grid tests
  test "battle intent triggers defense grid alert" do
    result = @ship.travel_to!(@destination, intent: :battle)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    assert @ship.under_defense_alert?
    assert_not_nil @ship.defense_engaged_at
  end

  test "trade intent does not trigger defense grid" do
    @ship.travel_to!(@destination, intent: :trade)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    refute @ship.under_defense_alert?
    assert_nil @ship.defense_engaged_at
  end

  test "defense grid applies combat status to hostile ships" do
    @ship.travel_to!(@destination, intent: :battle)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    # Ship should be in combat after defense grid engages
    assert_equal "combat", @ship.status
  end

  # Warp travel with intent
  test "warp travel also requires intent declaration" do
    WarpGate.create!(system_a: @origin, system_b: @destination)

    @ship.warp_to!(@destination, intent: :trade)

    assert_equal "trade", @ship.system_intent
    assert_equal @destination.id, @ship.current_system_id
  end

  test "warp battle triggers immediate defense grid" do
    WarpGate.create!(system_a: @origin, system_b: @destination)

    @ship.warp_to!(@destination, intent: :battle)

    assert_equal "combat", @ship.status
    assert @ship.under_defense_alert?
  end

  # System presence tracking
  test "system tracks hostile ships present" do
    @ship.travel_to!(@destination, intent: :battle)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    assert_includes @destination.hostile_ships, @ship
    refute_includes @destination.trading_ships, @ship
  end

  test "system tracks trading ships present" do
    @ship.travel_to!(@destination, intent: :trade)
    @ship.update!(arrival_at: 1.minute.ago)
    @ship.check_arrival!

    assert_includes @destination.trading_ships, @ship
    refute_includes @destination.hostile_ships, @ship
  end
end
