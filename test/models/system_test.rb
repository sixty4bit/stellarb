# frozen_string_literal: true

require "test_helper"

class SystemTest < ActiveSupport::TestCase
  # ===========================================
  # System Discovery Logic Tests
  # ===========================================

  test "peek returns procedurally generated data without persisting" do
    # Peek at coordinates that don't exist in DB
    data = System.peek(x: 100, y: 200, z: 300)

    assert_kind_of Hash, data
    assert_equal 100, data[:coordinates][:x]
    assert_equal 200, data[:coordinates][:y]
    assert_equal 300, data[:coordinates][:z]
    assert data[:name].present?
    assert data[:star_type].present?

    # Should NOT create a record
    assert_nil System.find_by(x: 100, y: 200, z: 300)
  end

  test "peek is deterministic - same coordinates always produce same result" do
    peek1 = System.peek(x: 500, y: 600, z: 700)
    peek2 = System.peek(x: 500, y: 600, z: 700)

    assert_equal peek1[:name], peek2[:name]
    assert_equal peek1[:star_type], peek2[:star_type]
    assert_equal peek1[:seed], peek2[:seed]
  end

  test "peek returns different data for different coordinates" do
    peek1 = System.peek(x: 100, y: 200, z: 300)
    peek2 = System.peek(x: 101, y: 200, z: 300)

    # Seeds should differ
    refute_equal peek1[:seed], peek2[:seed]
  end

  test "peek for The Cradle returns special data" do
    cradle = System.peek(x: 0, y: 0, z: 0)

    assert_equal "The Cradle", cradle[:name]
    assert_equal "yellow_dwarf", cradle[:star_type]
    assert_equal 0, cradle[:hazard_level]
    assert cradle[:special_properties][:tutorial_zone]
  end

  test "discover_at creates new system for first visitor" do
    user = User.create!(name: "Explorer", email: "explorer@test.com")

    assert_difference "System.count", 1 do
      system = System.discover_at(x: 100, y: 200, z: 300, user: user)

      assert_equal 100, system.x
      assert_equal 200, system.y
      assert_equal 300, system.z
      assert_equal user, system.discovered_by
      assert system.discovery_date.present?
    end
  end

  test "discover_at returns existing system without creating duplicate" do
    user1 = User.create!(name: "First Explorer", email: "first@test.com")
    user2 = User.create!(name: "Second Explorer", email: "second@test.com")

    # First discovery
    system1 = System.discover_at(x: 100, y: 200, z: 300, user: user1)

    # Second visit should return same system
    assert_no_difference "System.count" do
      system2 = System.discover_at(x: 100, y: 200, z: 300, user: user2)
      assert_equal system1.id, system2.id
      # Original discoverer should remain
      assert_equal user1, system2.discovered_by
    end
  end

  test "discover_at uses peeked data for name and properties" do
    user = User.create!(name: "Explorer", email: "explorer@test.com")
    peeked = System.peek(x: 500, y: 600, z: 700)

    system = System.discover_at(x: 500, y: 600, z: 700, user: user)

    # Name should match peeked name
    assert_equal peeked[:name], system.name
    # Properties should include star_type from peeked data
    assert_equal peeked[:star_type], system.properties["star_type"]
  end

  test "coordinate_hash is deterministic" do
    hash1 = System.coordinate_hash(100, 200, 300)
    hash2 = System.coordinate_hash(100, 200, 300)

    assert_equal hash1, hash2
    assert_equal 64, hash1.length # SHA256 hex
  end

  test "coordinate_hash differs for different coordinates" do
    hash1 = System.coordinate_hash(100, 200, 300)
    hash2 = System.coordinate_hash(101, 200, 300)

    refute_equal hash1, hash2
  end

  # ===========================================
  # System Ownership Tests
  # ===========================================

  test "owned? returns true when owner_id is present" do
    user = User.create!(name: "Owner", email: "owner@test.com")
    system = System.cradle
    system.update!(owner: user)

    assert system.owned?
  end

  test "owned? returns false when owner_id is nil" do
    system = System.cradle
    system.update!(owner: nil)

    refute system.owned?
  end

  test "owned_by? returns true for the actual owner" do
    user = User.create!(name: "Owner", email: "owner@test.com")
    system = System.cradle
    system.update!(owner: user)

    assert system.owned_by?(user)
  end

  test "owned_by? returns false for non-owner" do
    owner = User.create!(name: "Owner", email: "owner@test.com")
    other = User.create!(name: "Other", email: "other@test.com")
    system = System.cradle
    system.update!(owner: owner)

    refute system.owned_by?(other)
  end

  test "owned_by? returns false for nil user" do
    user = User.create!(name: "Owner", email: "owner@test.com")
    system = System.cradle
    system.update!(owner: user)

    refute system.owned_by?(nil)
  end

  test "owned_by? returns false for unowned system" do
    user = User.create!(name: "User", email: "user@test.com")
    system = System.cradle
    system.update!(owner: nil)

    refute system.owned_by?(user)
  end

  test "system belongs_to owner association" do
    user = User.create!(name: "Owner", email: "owner@test.com")
    system = System.cradle
    system.update!(owner: user)

    assert_equal user, system.owner
    assert_includes user.reload.owned_systems, system
  end

  # ===========================================
  # Base Prices Tests
  # ===========================================

  test "base_prices returns base_prices from properties" do
    system = System.cradle
    system.update!(properties: { "base_prices" => { "iron" => 100, "gold" => 500 } })

    assert_equal({ "iron" => 100, "gold" => 500 }, system.base_prices)
  end

  test "base_prices falls back to base_market_prices for backward compatibility" do
    system = System.cradle
    # Simulate old data with base_market_prices key
    system.update!(properties: { "base_market_prices" => { "iron" => 150, "fuel" => 50 } })

    assert_equal({ "iron" => 150, "fuel" => 50 }, system.base_prices)
  end

  test "base_prices prefers base_prices over base_market_prices" do
    system = System.cradle
    # Both keys present - should prefer base_prices
    system.update!(properties: {
      "base_prices" => { "iron" => 100 },
      "base_market_prices" => { "iron" => 999 }
    })

    assert_equal({ "iron" => 100 }, system.base_prices)
  end

  test "base_prices returns empty hash when no price data exists" do
    system = System.cradle
    system.update!(properties: {})

    assert_equal({}, system.base_prices)
  end

  # ===========================================
  # Negative Coordinate Tests
  # ===========================================

  test "system with negative coordinates is valid" do
    system = System.new(x: -100, y: -200, z: -300, name: "Negative System", short_id: "sy-neg1")
    system.properties = { star_type: "red_dwarf", planet_count: 2, hazard_level: 1, base_prices: {} }
    assert system.valid?, "System with negative coordinates should be valid: #{system.errors.full_messages}"
  end

  test "system at negative boundary is valid" do
    system = System.new(x: -999_999, y: -999_999, z: -999_999, name: "Edge System", short_id: "sy-edge1")
    system.properties = { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} }
    assert system.valid?, "System at negative boundary should be valid: #{system.errors.full_messages}"
  end

  test "system beyond negative boundary is invalid" do
    system = System.new(x: -1_000_000, y: 0, z: 0, name: "Too Far", short_id: "sy-toofar")
    system.properties = { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} }
    assert_not system.valid?, "System beyond -999_999 should be invalid"
  end
end
