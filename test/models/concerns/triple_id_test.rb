# frozen_string_literal: true

require "test_helper"

class TripleIdTest < ActiveSupport::TestCase
  # ===========================================
  # Triple-ID System Tests
  # Using User model as test subject
  # ===========================================

  test "generates uuid7 on create" do
    user = User.create!(name: "Test User", email: "test-uuid@example.com")

    assert user.uuid.present?
    assert_equal 36, user.uuid.length # Standard UUID format
    assert user.uuid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
  end

  test "uuid7 is time-sortable" do
    user1 = User.create!(name: "First", email: "first@example.com")
    sleep 0.01
    user2 = User.create!(name: "Second", email: "second@example.com")

    # UUID v7 has timestamp encoded at the beginning
    # So lexicographic sorting = chronological sorting
    assert user1.uuid < user2.uuid
  end

  test "uuid is immutable after creation" do
    user = User.create!(name: "Test User", email: "test-immutable@example.com")
    original_uuid = user.uuid

    user.update!(name: "Changed Name")
    user.reload

    assert_equal original_uuid, user.uuid
  end

  test "triple_id returns hash with all three identifiers" do
    user = User.create!(name: "Test User", email: "test-triple@example.com")
    triple = user.triple_id

    assert_kind_of Hash, triple
    assert_equal user.name, triple[:name]
    assert_equal user.short_id, triple[:short_id]
    assert_equal user.uuid, triple[:uuid]
  end

  test "short_id follows prefix convention" do
    user = User.create!(name: "Test User", email: "test-prefix@example.com")

    # User short_id should start with "u-"
    assert user.short_id.start_with?("u-")
  end

  # Test other models have consistent triple-id
  test "ship has triple_id" do
    user = User.create!(name: "Owner", email: "owner@example.com")
    system = System.create!(x: 0, y: 0, z: 0, name: "Test", discovered_by: user)
    ship = Ship.create!(
      name: "Test Ship",
      user: user,
      current_system: system,
      hull_size: "scout",
      race: "vex",
      variant_idx: 0,
      fuel: 100.0,
      status: "docked"
    )

    assert ship.uuid.present?
    assert ship.short_id.present?
    assert ship.name.present?

    triple = ship.triple_id
    assert_equal ship.name, triple[:name]
    assert_equal ship.short_id, triple[:short_id]
    assert_equal ship.uuid, triple[:uuid]
  end

  test "building has triple_id" do
    user = User.create!(name: "Owner", email: "owner-bld@example.com")
    system = System.create!(x: 0, y: 0, z: 0, name: "Test", discovered_by: user)
    building = Building.create!(
      name: "Test Building",
      user: user,
      system: system,
      function: "extraction",
      race: "vex",
      tier: 1,
      status: "active"
    )

    assert building.uuid.present?
    assert building.short_id.present?
    assert building.name.present?

    triple = building.triple_id
    assert_equal building.name, triple[:name]
  end

  test "system has triple_id" do
    user = User.create!(name: "Explorer", email: "explorer-sys@example.com")
    system = System.create!(x: 0, y: 0, z: 0, name: "Alpha Centauri", discovered_by: user)

    assert system.uuid.present?
    assert system.short_id.present?
    assert system.name.present?

    triple = system.triple_id
    assert_equal system.name, triple[:name]
    assert system.short_id.start_with?("sy-")
  end

  test "route has triple_id" do
    user = User.create!(name: "Trader", email: "trader@example.com")
    route = Route.create!(
      name: "Trade Route Alpha",
      user: user
    )

    assert route.uuid.present?
    assert route.short_id.present?
    assert route.name.present?

    triple = route.triple_id
    assert_equal route.name, triple[:name]
    assert route.short_id.start_with?("rt-")
  end
end
