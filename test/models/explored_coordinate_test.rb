# frozen_string_literal: true

require "test_helper"

class ExploredCoordinateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # ===========================================
  # Validations
  # ===========================================

  test "requires user" do
    coord = ExploredCoordinate.new(x: 0, y: 0, z: 0)
    assert_not coord.valid?
    assert_includes coord.errors[:user], "must exist"
  end

  test "requires x, y, z coordinates" do
    coord = ExploredCoordinate.new(user: @user)
    assert_not coord.valid?
    assert_includes coord.errors[:x], "can't be blank"
    assert_includes coord.errors[:y], "can't be blank"
    assert_includes coord.errors[:z], "can't be blank"
  end

  test "enforces uniqueness of coordinates per user" do
    ExploredCoordinate.create!(user: @user, x: 1, y: 2, z: 3)
    duplicate = ExploredCoordinate.new(user: @user, x: 1, y: 2, z: 3)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:x], "has already been taken"
  end

  test "allows same coordinates for different users" do
    other_user = users(:pilot)
    ExploredCoordinate.create!(user: @user, x: 1, y: 2, z: 3)
    coord = ExploredCoordinate.new(user: other_user, x: 1, y: 2, z: 3)

    assert coord.valid?
  end

  # ===========================================
  # Scopes
  # ===========================================

  test ".with_systems returns only coordinates with systems" do
    with_system = ExploredCoordinate.create!(user: @user, x: 1, y: 0, z: 0, has_system: true)
    ExploredCoordinate.create!(user: @user, x: 2, y: 0, z: 0, has_system: false)

    results = @user.explored_coordinates.with_systems
    assert_includes results, with_system
    assert_equal 1, results.count
  end

  test ".empty returns only coordinates without systems" do
    ExploredCoordinate.create!(user: @user, x: 1, y: 0, z: 0, has_system: true)
    empty = ExploredCoordinate.create!(user: @user, x: 2, y: 0, z: 0, has_system: false)

    results = @user.explored_coordinates.empty
    assert_includes results, empty
    assert_equal 1, results.count
  end

  # ===========================================
  # Class Methods
  # ===========================================

  test ".explored? returns true when coordinate has been explored" do
    ExploredCoordinate.create!(user: @user, x: 5, y: 5, z: 5)

    assert ExploredCoordinate.explored?(user: @user, x: 5, y: 5, z: 5)
  end

  test ".explored? returns false when coordinate has not been explored" do
    assert_not ExploredCoordinate.explored?(user: @user, x: 99, y: 99, z: 99)
  end

  test ".mark_explored! creates new record" do
    assert_difference -> { ExploredCoordinate.count } do
      coord = ExploredCoordinate.mark_explored!(user: @user, x: 10, y: 20, z: 30)

      assert_equal 10, coord.x
      assert_equal 20, coord.y
      assert_equal 30, coord.z
      assert_not coord.has_system
    end
  end

  test ".mark_explored! with has_system flag" do
    coord = ExploredCoordinate.mark_explored!(user: @user, x: 10, y: 20, z: 30, has_system: true)

    assert coord.has_system
  end

  test ".mark_explored! returns existing record if already explored" do
    existing = ExploredCoordinate.create!(user: @user, x: 10, y: 20, z: 30)

    assert_no_difference -> { ExploredCoordinate.count } do
      coord = ExploredCoordinate.mark_explored!(user: @user, x: 10, y: 20, z: 30)
      assert_equal existing.id, coord.id
    end
  end

  # ===========================================
  # Instance Methods (Orbital)
  # ===========================================

  test "distance_from_origin calculates correctly" do
    coord = ExploredCoordinate.new(x: 3, y: 4, z: 0)
    assert_equal 5.0, coord.distance_from_origin

    coord2 = ExploredCoordinate.new(x: 1, y: 1, z: 1)
    assert_in_delta Math.sqrt(3), coord2.distance_from_origin, 0.001
  end

  test "orbital_distance rounds to nearest integer" do
    # Distance 1.4 should round to 1
    coord1 = ExploredCoordinate.new(x: 1, y: 1, z: 0) # distance ~1.41
    assert_equal 1, coord1.orbital_distance

    # Distance 1.7 should round to 2
    coord2 = ExploredCoordinate.new(x: 1, y: 1, z: 1) # distance ~1.73
    assert_equal 2, coord2.orbital_distance

    # Origin should be 0
    coord3 = ExploredCoordinate.new(x: 0, y: 0, z: 0)
    assert_equal 0, coord3.orbital_distance
  end

  test "has_system defaults to false" do
    coord = ExploredCoordinate.create!(user: @user, x: 99, y: 99, z: 99)
    assert_equal false, coord.has_system
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to user" do
    coord = ExploredCoordinate.create!(user: @user, x: 0, y: 0, z: 0)

    assert_equal @user, coord.user
  end

  test "user has_many explored_coordinates" do
    ExploredCoordinate.create!(user: @user, x: 1, y: 0, z: 0)
    ExploredCoordinate.create!(user: @user, x: 2, y: 0, z: 0)

    assert_equal 2, @user.explored_coordinates.count
  end

  test "destroyed when user is destroyed" do
    ExploredCoordinate.create!(user: @user, x: 1, y: 0, z: 0)

    assert_difference -> { ExploredCoordinate.count }, -1 do
      @user.destroy
    end
  end
end
