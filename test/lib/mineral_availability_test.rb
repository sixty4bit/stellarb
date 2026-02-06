# frozen_string_literal: true

require "test_helper"

class MineralAvailabilityTest < ActiveSupport::TestCase
  # =========================================
  # Distance-based tier availability tests
  # =========================================

  test "near Cradle (< 100 units) only has Tier 1-2 minerals" do
    available = MineralAvailability.for_system(star_type: "yellow_dwarf", x: 0, y: 0, z: 0)

    # Should have common and uncommon minerals
    assert available.any? { |m| m[:tier] == :common }
    assert available.any? { |m| m[:tier] == :uncommon }

    # Should NOT have rare, exotic, or futuristic
    assert_not available.any? { |m| m[:tier] == :rare }
    assert_not available.any? { |m| m[:tier] == :exotic }
    assert_not available.any? { |m| m[:tier] == :futuristic }
  end

  test "mid-range (100-500 units) has Tier 1-3 minerals" do
    available = MineralAvailability.for_system(star_type: "yellow_dwarf", x: 300, y: 0, z: 0)

    assert available.any? { |m| m[:tier] == :common }
    assert available.any? { |m| m[:tier] == :uncommon }
    assert available.any? { |m| m[:tier] == :rare }

    assert_not available.any? { |m| m[:tier] == :exotic }
    assert_not available.any? { |m| m[:tier] == :futuristic }
  end

  test "deep space (> 500 units) has Tier 1-4 minerals" do
    available = MineralAvailability.for_system(star_type: "yellow_dwarf", x: 600, y: 0, z: 0)

    assert available.any? { |m| m[:tier] == :common }
    assert available.any? { |m| m[:tier] == :uncommon }
    assert available.any? { |m| m[:tier] == :rare }
    assert available.any? { |m| m[:tier] == :exotic }

    # Still no futuristic without special star type
    assert_not available.any? { |m| m[:tier] == :futuristic }
  end

  # =========================================
  # Star type futuristic mineral tests
  # =========================================

  test "neutron star systems have Stellarium" do
    available = MineralAvailability.for_system(star_type: "neutron_star", x: 1000, y: 0, z: 0)

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    assert_not_nil stellarium, "Neutron star should have Stellarium"
  end

  test "black hole proximity systems have Voidite" do
    available = MineralAvailability.for_system(star_type: "black_hole_proximity", x: 1000, y: 0, z: 0)

    voidite = available.find { |m| m[:name] == "Voidite" }
    assert_not_nil voidite, "Black hole proximity should have Voidite"
  end

  test "binary systems have Chronite" do
    available = MineralAvailability.for_system(star_type: "binary_system", x: 1000, y: 0, z: 0)

    chronite = available.find { |m| m[:name] == "Chronite" }
    assert_not_nil chronite, "Binary system should have Chronite"
  end

  test "blue giant systems have Plasmaite" do
    available = MineralAvailability.for_system(star_type: "blue_giant", x: 1000, y: 0, z: 0)

    plasmaite = available.find { |m| m[:name] == "Plasmaite" }
    assert_not_nil plasmaite, "Blue giant should have Plasmaite"
  end

  test "yellow giant systems have Solarite" do
    available = MineralAvailability.for_system(star_type: "yellow_giant", x: 1000, y: 0, z: 0)

    solarite = available.find { |m| m[:name] == "Solarite" }
    assert_not_nil solarite, "Yellow giant should have Solarite"
  end

  test "very deep space (> 5000 units) has Darkstone" do
    available = MineralAvailability.for_system(star_type: "yellow_dwarf", x: 5001, y: 0, z: 0)

    darkstone = available.find { |m| m[:name] == "Darkstone" }
    assert_not_nil darkstone, "Deep space (>5000 units) should have Darkstone"
  end

  test "futuristic minerals require both correct star type AND far enough distance" do
    # Neutron star but too close to Cradle
    available = MineralAvailability.for_system(star_type: "neutron_star", x: 50, y: 0, z: 0)

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    assert_nil stellarium, "Futuristic minerals should not appear near Cradle even with right star type"
  end

  # =========================================
  # Utility method tests
  # =========================================

  test "available_tiers returns correct tiers by distance" do
    assert_equal [:common, :uncommon], MineralAvailability.available_tiers(50)
    assert_equal [:common, :uncommon, :rare], MineralAvailability.available_tiers(300)
    assert_equal [:common, :uncommon, :rare, :exotic], MineralAvailability.available_tiers(600)
  end

  test "distance_from_cradle calculates correctly" do
    assert_in_delta 0, MineralAvailability.distance_from_cradle(0, 0, 0), 0.01
    assert_in_delta 100, MineralAvailability.distance_from_cradle(100, 0, 0), 0.01
    assert_in_delta Math.sqrt(200), MineralAvailability.distance_from_cradle(10, 10, 0), 0.01
  end
end
