require "test_helper"

class ShipChaosTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(profile_completed_at: Time.current) unless @user.profile_completed_at
    @system = System.cradle
    @ship = Ship.create!(
      name: "Chaos Test Ship",
      user: @user,
      race: "grelmak",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 200,
      status: "docked",
      current_system: @system,
      ship_attributes: { "hull_points" => 100, "cargo_capacity" => 200 }
    )
  end

  test "chaos_check! returns nil for non-grelmak ships" do
    @ship.update!(race: "vex")
    result = @ship.chaos_check!
    assert_nil result
  end

  test "chaos_check! does nothing when roll is above threshold" do
    # Seed random to get a high roll (no trigger)
    rng = Random.new(42)
    # Find a seed that gives >= 0.15
    seed = (0..100).find { |s| Random.new(s).rand >= Ship::GRELMAK_CHAOS_FACTOR }
    rng = Random.new(seed)

    messages_before = Message.count
    @ship.chaos_check!(rng: rng)
    assert_equal messages_before, Message.count
  end

  test "chaos_check! triggers hull damage event" do
    # Find seed: rand < 0.15 AND event index 0 (hull damage)
    seed = find_seed(event_index: 0)
    rng = Random.new(seed)

    @ship.chaos_check!(rng: rng)
    @ship.reload

    assert @ship.hull_points < 100, "Hull points should decrease"
    assert @ship.hull_points >= 90, "Hull points should not drop below 90"
    assert Message.where(user: @user, category: "chaos").exists?
  end

  test "chaos_check! triggers fuel leak event" do
    seed = find_seed(event_index: 1)
    rng = Random.new(seed)

    @ship.chaos_check!(rng: rng)
    @ship.reload

    assert_equal 90, @ship.fuel, "Should lose 10% fuel"
    assert Message.where(user: @user, category: "chaos").exists?
  end

  test "chaos_check! triggers cargo spill event with cargo" do
    @ship.update!(cargo: { "ore" => 5, "water" => 3 })
    seed = find_seed(event_index: 2)
    rng = Random.new(seed)

    before_total = @ship.total_cargo_weight
    @ship.chaos_check!(rng: rng)
    @ship.reload

    assert_equal before_total - 1, @ship.total_cargo_weight, "Should lose 1 cargo unit"
    assert Message.where(user: @user, category: "chaos").exists?
  end

  test "chaos_check! cargo spill with no cargo just sends message" do
    @ship.update!(cargo: {})
    seed = find_seed(event_index: 2)
    rng = Random.new(seed)

    @ship.chaos_check!(rng: rng)
    @ship.reload

    assert_equal({}, @ship.cargo)
    assert Message.where(user: @user, category: "chaos").exists?
  end

  test "chaos_check! triggers navigation glitch (no mechanical effect)" do
    seed = find_seed(event_index: 3)
    rng = Random.new(seed)

    hp_before = @ship.hull_points
    fuel_before = @ship.fuel

    @ship.chaos_check!(rng: rng)
    @ship.reload

    assert_equal hp_before, @ship.hull_points
    assert_equal fuel_before, @ship.fuel
    assert Message.where(user: @user, category: "chaos").exists?
  end

  test "check_arrival! calls chaos_check! for grelmak ships" do
    destination = System.find_by(name: "Alpha Centauri") || System.create!(
      name: "Alpha Centauri", x: 1, y: 1, z: 1,
      properties: { "star_type" => "G", "hazard_level" => 0 },
      base_prices: { "fuel" => 10 }
    )

    @ship.update!(
      status: "in_transit",
      destination_system: destination,
      arrival_at: 1.minute.ago,
      pending_intent: "trade"
    )

    # Should not error - chaos_check! is called during arrival
    @ship.check_arrival!
    @ship.reload
    assert_equal "docked", @ship.status
  end

  private

  def find_seed(event_index:)
    (0..1000).find do |s|
      rng = Random.new(s)
      triggers = rng.rand < Ship::GRELMAK_CHAOS_FACTOR
      next false unless triggers
      rng.rand(4) == event_index
    end
  end
end
