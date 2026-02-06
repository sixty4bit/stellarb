# frozen_string_literal: true

require "test_helper"

class MiningServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
  end

  # ==========================================
  # Mining in Correct System Type Triggers Discovery
  # ==========================================

  test "mining in neutron star system discovers Stellarium" do
    system = create_system_with_star_type("neutron_star", x: 1000, y: 0, z: 0)
    
    assert_not @user.mineral_discovered?("Stellarium")
    
    result = MiningService.call(user: @user, system: system)
    
    assert result.success?
    assert @user.reload.mineral_discovered?("Stellarium")
  end

  test "mining in black hole proximity discovers Voidite" do
    system = create_system_with_star_type("black_hole_proximity", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert @user.reload.mineral_discovered?("Voidite")
  end

  test "mining in binary system discovers Chronite" do
    system = create_system_with_star_type("binary_system", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert @user.reload.mineral_discovered?("Chronite")
  end

  test "mining in blue giant discovers Plasmaite" do
    system = create_system_with_star_type("blue_giant", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert @user.reload.mineral_discovered?("Plasmaite")
  end

  test "mining in yellow giant discovers Solarite" do
    system = create_system_with_star_type("yellow_giant", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert @user.reload.mineral_discovered?("Solarite")
  end

  test "mining in red giant (ice giant) discovers Cryonite" do
    system = create_system_with_star_type("red_giant", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert @user.reload.mineral_discovered?("Cryonite")
  end

  test "mining in deep space (> 5000 units) discovers Darkstone" do
    system = create_system_with_star_type("yellow_dwarf", x: 5001, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert @user.reload.mineral_discovered?("Darkstone")
  end

  # ==========================================
  # Distance Requirements
  # ==========================================

  test "mining in neutron star too close to Cradle does not discover" do
    # Neutron star but distance < 500 from Cradle
    system = create_system_with_star_type("neutron_star", x: 50, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert result.success?
    assert_not @user.reload.mineral_discovered?("Stellarium"),
      "Should not discover Stellarium in neutron star close to Cradle"
  end

  test "mining in ordinary system does not discover futuristic minerals" do
    system = create_system_with_star_type("yellow_dwarf", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert result.success?
    assert_empty @user.reload.discovered_futuristic_minerals
  end

  # ==========================================
  # Discovery Persistence
  # ==========================================

  test "mining again does not duplicate discovery" do
    system = create_system_with_star_type("neutron_star", x: 1000, y: 0, z: 0)
    
    MiningService.call(user: @user, system: system)
    MiningService.call(user: @user, system: system)
    
    discoveries = @user.mineral_discoveries.where(mineral_name: "Stellarium")
    assert_equal 1, discoveries.count
  end

  test "discovery tracks which system it was found in" do
    system = create_system_with_star_type("neutron_star", x: 1000, y: 0, z: 0)
    
    MiningService.call(user: @user, system: system)
    
    discovery = @user.mineral_discoveries.find_by(mineral_name: "Stellarium")
    assert_equal system, discovery.discovered_in_system
  end

  # ==========================================
  # Result Contains Discovery Info
  # ==========================================

  test "result includes newly discovered minerals" do
    system = create_system_with_star_type("neutron_star", x: 1000, y: 0, z: 0)
    
    result = MiningService.call(user: @user, system: system)
    
    assert_includes result.discoveries, "Stellarium"
  end

  test "result does not include already discovered minerals" do
    system = create_system_with_star_type("neutron_star", x: 1000, y: 0, z: 0)
    
    # First mining - should discover
    first_result = MiningService.call(user: @user, system: system)
    assert_includes first_result.discoveries, "Stellarium"
    
    # Second mining - should not re-discover
    second_result = MiningService.call(user: @user, system: system)
    assert_not_includes second_result.discoveries, "Stellarium"
  end

  private

  def create_system_with_star_type(star_type, x:, y:, z:)
    System.create!(
      x: x, y: y, z: z,
      name: "Test System #{star_type}",
      short_id: "sys-#{SecureRandom.hex(4)}",
      properties: {
        "star_type" => star_type,
        "planet_count" => 3,
        "hazard_level" => 10,
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron"], "abundance" => "medium" }
        }
      }
    )
  end
end
