# frozen_string_literal: true

require "test_helper"

class FuturisticMineralVisibilityTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
  end

  # ==========================================
  # Futuristic minerals are hidden until discovered
  # ==========================================

  test "futuristic minerals are NOT visible in MineralAvailability without discovery" do
    # Even in a neutron star far from Cradle, Stellarium should be hidden until discovered
    available = MineralAvailability.for_system_with_discoveries(
      star_type: "neutron_star",
      x: 1000, y: 0, z: 0,
      user: @user
    )

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    assert_nil stellarium, "Stellarium should be hidden until discovered"
  end

  test "futuristic minerals become visible after discovery" do
    # First mine to trigger discovery
    system = create_neutron_star_system
    MiningService.call(user: @user, system: system)

    # Now should be visible
    available = MineralAvailability.for_system_with_discoveries(
      star_type: "neutron_star",
      x: 1000, y: 0, z: 0,
      user: @user
    )

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    assert_not_nil stellarium, "Stellarium should be visible after discovery"
  end

  test "only discovered futuristic minerals are visible" do
    # Discover Stellarium
    system = create_neutron_star_system
    MiningService.call(user: @user, system: system)

    # In a system that could have both Stellarium and Voidite
    # Only Stellarium should be visible (the one discovered)
    available = MineralAvailability.for_system_with_discoveries(
      star_type: "neutron_star",
      x: 1000, y: 0, z: 0,
      user: @user
    )

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    voidite = available.find { |m| m[:name] == "Voidite" }

    assert_not_nil stellarium, "Discovered Stellarium should be visible"
    assert_nil voidite, "Undiscovered Voidite should remain hidden"
  end

  test "non-futuristic minerals are always visible" do
    # Regular minerals should show regardless of discovery state
    available = MineralAvailability.for_system_with_discoveries(
      star_type: "yellow_dwarf",
      x: 0, y: 0, z: 0,
      user: @user
    )

    # Common minerals should always be there
    iron = available.find { |m| m[:name] == "Iron" }
    assert_not_nil iron, "Non-futuristic minerals should always be visible"
  end

  test "other players discoveries do not affect visibility" do
    other_user = users(:traveler)

    # Other user discovers Stellarium
    system = create_neutron_star_system
    MiningService.call(user: other_user, system: system)

    # Original user still cannot see Stellarium
    available = MineralAvailability.for_system_with_discoveries(
      star_type: "neutron_star",
      x: 1000, y: 0, z: 0,
      user: @user
    )

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    assert_nil stellarium, "Should not see minerals discovered by other players"
  end

  # ==========================================
  # Legacy method still works (for non-player contexts)
  # ==========================================

  test "original for_system method still returns all minerals" do
    # Without player context, all valid minerals are returned
    available = MineralAvailability.for_system(
      star_type: "neutron_star",
      x: 1000, y: 0, z: 0
    )

    stellarium = available.find { |m| m[:name] == "Stellarium" }
    assert_not_nil stellarium, "Legacy method should return all minerals"
  end

  private

  def create_neutron_star_system
    System.create!(
      x: 1000, y: 0, z: 0,
      name: "Neutron Test",
      short_id: "sys-#{SecureRandom.hex(4)}",
      properties: {
        "star_type" => "neutron_star",
        "planet_count" => 2,
        "hazard_level" => 50,
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron"], "abundance" => "low" }
        }
      }
    )
  end
end
