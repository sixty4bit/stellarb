require "test_helper"

class ShipRacesTest < ActiveSupport::TestCase
  setup do
    @system = systems(:cradle)
    @user = users(:one)
  end

  test "RACES includes grelmak and mechari" do
    assert_includes Ship::RACES, "grelmak"
    assert_includes Ship::RACES, "mechari"
  end

  test "GRELMAK_CHAOS_FACTOR is defined" do
    assert_equal 0.15, Ship::GRELMAK_CHAOS_FACTOR
  end

  test "grelmak racial cost modifier is 0.75" do
    assert_equal 0.75, Ship::RACIAL_COST_MODIFIERS["grelmak"]
  end

  test "mechari racial cost modifier is 1.25" do
    assert_equal 1.25, Ship::RACIAL_COST_MODIFIERS["mechari"]
  end

  test "grelmak gets 1.15 boost to all base stats" do
    ship = Ship.new(
      name: "Gremlin",
      race: "grelmak",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      user: @user
    )
    ship.valid? # triggers callbacks

    attrs = ship.ship_attributes
    assert_equal (100 * 1.15).to_f, attrs["cargo_capacity"].to_f
    assert_equal (10 * 1.15).to_f, attrs["sensor_range"].to_f
    assert_equal (100 * 1.15).to_f, attrs["hull_points"].to_f
    assert_equal (50 * 1.15).to_f, attrs["maneuverability"].to_f
  end

  test "mechari gets fuel_efficiency boost and maintenance reduction" do
    ship = Ship.new(
      name: "Clanker",
      race: "mechari",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      user: @user
    )
    ship.valid?

    attrs = ship.ship_attributes
    assert_in_delta 1.0 * 1.3, attrs["fuel_efficiency"].to_f, 0.01
    assert_in_delta 10 * 0.6, attrs["maintenance_rate"].to_f, 0.01
  end

  test "mechari crew_slots max reduced by 1" do
    ship = Ship.new(
      name: "Clanker",
      race: "mechari",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      user: @user
    )
    ship.valid?

    crew_slots = ship.ship_attributes["crew_slots"]
    assert_equal 3, crew_slots["max"] || crew_slots[:max]
  end

  test "grelmak ship can be created and saved" do
    ship = Ship.create!(
      name: "Gremlin Ship",
      race: "grelmak",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      user: @user
    )
    assert ship.persisted?
  end

  test "mechari ship can be created and saved" do
    ship = Ship.create!(
      name: "Mechari Ship",
      race: "mechari",
      hull_size: "frigate",
      variant_idx: 0,
      fuel: 100,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      user: @user
    )
    assert ship.persisted?
  end
end
