# frozen_string_literal: true

require "test_helper"

class MineralDiscoveryTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @system = System.discover_at(x: 1000, y: 0, z: 0, user: @user)
  end

  # ==========================================
  # Basic Model Tests
  # ==========================================

  test "belongs to user" do
    discovery = MineralDiscovery.new(
      user: @user,
      mineral_name: "Stellarium",
      discovered_in_system: @system
    )
    assert_equal @user, discovery.user
  end

  test "belongs to discovered_in_system" do
    discovery = MineralDiscovery.new(
      user: @user,
      mineral_name: "Stellarium",
      discovered_in_system: @system
    )
    assert_equal @system, discovery.discovered_in_system
  end

  test "requires user" do
    discovery = MineralDiscovery.new(mineral_name: "Stellarium")
    assert_not discovery.valid?
    assert_includes discovery.errors[:user], "must exist"
  end

  test "requires mineral_name" do
    discovery = MineralDiscovery.new(user: @user)
    assert_not discovery.valid?
    assert_includes discovery.errors[:mineral_name], "can't be blank"
  end

  test "mineral_name must be a valid futuristic mineral" do
    discovery = MineralDiscovery.new(
      user: @user,
      mineral_name: "Iron" # not futuristic
    )
    assert_not discovery.valid?
    assert_includes discovery.errors[:mineral_name], "must be a futuristic mineral"
  end

  test "valid with futuristic mineral" do
    Minerals::FUTURISTIC.each do |mineral|
      discovery = MineralDiscovery.new(
        user: @user,
        mineral_name: mineral[:name]
      )
      assert discovery.valid?, "Expected #{mineral[:name]} to be valid"
    end
  end

  test "unique per user and mineral combination" do
    MineralDiscovery.create!(
      user: @user,
      mineral_name: "Stellarium",
      discovered_in_system: @system
    )

    duplicate = MineralDiscovery.new(
      user: @user,
      mineral_name: "Stellarium"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:mineral_name], "has already been taken"
  end

  test "same mineral can be discovered by different users" do
    other_user = users(:traveler)
    
    MineralDiscovery.create!(
      user: @user,
      mineral_name: "Stellarium",
      discovered_in_system: @system
    )

    other_discovery = MineralDiscovery.new(
      user: other_user,
      mineral_name: "Stellarium"
    )
    assert other_discovery.valid?
  end

  # ==========================================
  # Discovery Tracking
  # ==========================================

  test "user can check if mineral is discovered" do
    assert_not @user.mineral_discovered?("Stellarium")
    
    MineralDiscovery.create!(
      user: @user,
      mineral_name: "Stellarium",
      discovered_in_system: @system
    )
    
    assert @user.mineral_discovered?("Stellarium")
  end

  test "user can list discovered futuristic minerals" do
    assert_empty @user.discovered_futuristic_minerals
    
    MineralDiscovery.create!(
      user: @user,
      mineral_name: "Stellarium",
      discovered_in_system: @system
    )
    MineralDiscovery.create!(
      user: @user,
      mineral_name: "Voidite",
      discovered_in_system: @system
    )
    
    assert_equal ["Stellarium", "Voidite"].sort, @user.discovered_futuristic_minerals.sort
  end

  # ==========================================
  # Discovery Timestamps
  # ==========================================

  test "records discovered_at timestamp" do
    freeze_time do
      discovery = MineralDiscovery.create!(
        user: @user,
        mineral_name: "Stellarium",
        discovered_in_system: @system
      )
      assert_equal Time.current, discovery.discovered_at
    end
  end
end
