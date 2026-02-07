# frozen_string_literal: true

require "test_helper"

class ExplorationServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "explorer@example.com",
      name: "Explorer Test",
      tutorial_phase: :proving_ground
    )
    # Start at The Cradle (0,0,0)
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @ship = Ship.create!(
      user: @user,
      name: "Explorer Ship",
      hull_size: "scout",
      race: "solari",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @cradle
    )
    # Record visit to cradle
    SystemVisit.record_visit(@user, @cradle)

    @service = ExplorationService.new(@user, @ship)
  end

  # ===========================================
  # closest_unexplored tests
  # ===========================================

  test "closest_unexplored returns nearest unexplored coordinates" do
    result = @service.closest_unexplored

    assert_not_nil result
    assert result.key?(:x)
    assert result.key?(:y)
    assert result.key?(:z)
    assert result.key?(:distance)
  end

  test "closest_unexplored excludes current position when explored" do
    result = @service.closest_unexplored

    # Should not return (0,0,0) since we visited it
    refute_equal [0, 0, 0], [result[:x], result[:y], result[:z]]
  end

  test "closest_unexplored returns coordinates on valid grid" do
    result = @service.closest_unexplored

    assert ExplorationService::VALID_COORDS.include?(result[:x])
    assert ExplorationService::VALID_COORDS.include?(result[:y])
    assert ExplorationService::VALID_COORDS.include?(result[:z])
  end

  test "closest_unexplored calculates distance correctly" do
    result = @service.closest_unexplored

    # From (0,0,0), the closest valid unexplored point should be
    # one of the adjacent points: (1,0,0), (0,1,0), or (0,0,1)
    # Distance should be 1
    assert_equal 1.0, result[:distance]
  end


  test "closest_unexplored filters by direction spinward" do
    result = @service.closest_unexplored(direction: :spinward)

    # Spinward is positive X direction
    # From (0,0,0), should be (1,0,0)
    assert_not_nil result
    assert result[:x] > @cradle.x, "Spinward should have higher X"
  end

  test "closest_unexplored filters by direction north" do
    result = @service.closest_unexplored(direction: :north)

    # North is positive Y direction
    assert_not_nil result
    assert result[:y] > @cradle.y, "North should have higher Y"
  end

  test "closest_unexplored filters by direction up" do
    result = @service.closest_unexplored(direction: :up)

    # Up is positive Z direction
    assert_not_nil result
    assert result[:z] > @cradle.z, "Up should have higher Z"
  end

  test "closest_unexplored filters by direction antispinward into negative space" do
    result = @service.closest_unexplored(direction: :antispinward)

    assert_not_nil result
    assert result[:x] < @cradle.x, "Antispinward should have lower X (negative)"
    assert result[:x] < 0, "From origin, antispinward should find negative X"
  end

  test "closest_unexplored filters by direction south into negative space" do
    result = @service.closest_unexplored(direction: :south)

    assert_not_nil result
    assert result[:y] < @cradle.y, "South should have lower Y (negative)"
    assert result[:y] < 0, "From origin, south should find negative Y"
  end

  test "closest_unexplored filters by direction down into negative space" do
    result = @service.closest_unexplored(direction: :down)

    assert_not_nil result
    assert result[:z] < @cradle.z, "Down should have lower Z (negative)"
    assert result[:z] < 0, "From origin, down should find negative Z"
  end

  test "all six directions find candidates from origin" do
    %i[spinward antispinward north south up down].each do |dir|
      result = @service.closest_unexplored(direction: dir)
      assert_not_nil result, "Direction #{dir} should find candidates"
    end
  end

  test "closest_unexplored returns nil when no coordinates in direction" do
    # Move ship to corner (9,9,9) and look spinward (positive X)
    corner_system = System.discover_at(x: 9, y: 9, z: 9, user: @user)
    @ship.update!(current_system: corner_system)
    SystemVisit.record_visit(@user, corner_system)

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored(direction: :spinward)

    # No valid coordinates with X > 9
    assert_nil result
  end

  # ===========================================
  # all_unexplored tests
  # ===========================================

  test "all_unexplored filters by direction and returns sorted" do
    results = @service.all_unexplored(direction: :spinward, limit: 10)

    assert_equal 10, results.size
    # All results should have X > current position (0)
    results.each do |r|
      assert r[:x] > @cradle.x, "Spinward results should have X > #{@cradle.x}"
    end
    # Should be sorted by distance
    distances = results.map { |r| r[:distance] }
    assert_equal distances.sort, distances
  end

  # ===========================================
  # Progress tracking tests
  # ===========================================

  test "total_coordinates returns 6859" do
    assert_equal 6859, @service.total_coordinates
  end

  test "explored_count tracks visited valid coordinates" do
    # Started with 1 visit (Cradle at 0,0,0)
    assert_equal 1, @service.explored_count
  end

  test "explored_count ignores non-grid coordinates" do
    # Visit a system not on the exploration grid (outside -9..9)
    off_grid = System.discover_at(x: 20, y: 20, z: 20, user: @user)
    SystemVisit.record_visit(@user, off_grid)

    service = ExplorationService.new(@user, @ship)

    # Should still only count the one valid grid coordinate
    assert_equal 1, service.explored_count
  end

  test "all_explored? returns false when unexplored remain" do
    refute @service.all_explored?
  end


  test "progress_percentage calculates correctly" do
    # 1 out of 6859 explored
    assert_in_delta 0.01, @service.progress_percentage, 0.01

    # Visit a few more
    sys1 = System.discover_at(x: 3, y: 0, z: 0, user: @user)
    sys2 = System.discover_at(x: 0, y: 3, z: 0, user: @user)
    SystemVisit.record_visit(@user, sys1)
    SystemVisit.record_visit(@user, sys2)

    service = ExplorationService.new(@user, @ship)
    # 3 out of 6859
    assert_in_delta 0.04, service.progress_percentage, 0.01
  end

  # ===========================================
  # Orbital exploration tests
  # ===========================================

  test "closest_unexplored_orbital returns origin first when at origin" do
    # Clear all visits to start fresh
    @user.system_visits.destroy_all
    @user.explored_coordinates.destroy_all

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored_orbital

    # Should return origin (0,0,0) as it's at distance 0
    assert_not_nil result
    assert_equal 0, result[:x]
    assert_equal 0, result[:y]
    assert_equal 0, result[:z]
  end

  test "closest_unexplored_orbital expands to next ring after origin explored" do
    # Origin is already explored (via setup)
    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored_orbital

    # Should return a coordinate at distance 1 (next ring)
    assert_not_nil result
    distance = Math.sqrt(result[:x]**2 + result[:y]**2 + result[:z]**2)
    assert_equal 1.0, distance
  end


  test "closest_unexplored_orbital prioritizes same orbital distance" do
    # Move ship to (3,3,3) - orbital distance ~5.2
    new_system = System.discover_at(x: 3, y: 3, z: 3, user: @user)
    @ship.update!(current_system: new_system)
    SystemVisit.record_visit(@user, new_system)

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored_orbital

    # Should find coordinate at similar orbital distance (~5.2)
    assert_not_nil result
    result_distance = Math.sqrt(result[:x]**2 + result[:y]**2 + result[:z]**2)
    ship_distance = Math.sqrt(3**2 + 3**2 + 3**2)
    
    # Should be within tolerance of same orbital ring
    assert_in_delta ship_distance, result_distance, 1.0
  end

  # ===========================================
  # Edge cases
  # ===========================================

  test "works when ship has no current system" do
    @ship.update!(
      current_system: nil,
      location_x: 5,
      location_y: 5,
      location_z: 5
    )

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored

    # Should return a result - defaults to (0,0,0) when no system
    assert_not_nil result
    assert_equal 1.0, result[:distance]
  end

  test "distance from non-origin position calculated correctly" do
    # Move ship to (3,3,3)
    new_system = System.discover_at(x: 3, y: 3, z: 3, user: @user)
    @ship.update!(current_system: new_system)
    SystemVisit.record_visit(@user, new_system)

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored

    # From (3,3,3), closest should be distance 1 (adjacent on any axis)
    assert_equal 1.0, result[:distance]
  end

  test "tie-breaking is deterministic" do
    # From (0,0,0), points (3,0,0), (0,3,0), (0,0,3) are all distance 3
    # min_by should return consistent results
    result1 = @service.closest_unexplored
    result2 = @service.closest_unexplored

    assert_equal result1, result2
  end
end
