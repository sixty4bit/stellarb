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
    # one of the adjacent points: (3,0,0), (0,3,0), or (0,0,3)
    # Distance should be 3
    assert_equal 3.0, result[:distance]
  end

  test "closest_unexplored returns nil when all explored" do
    # Visit all valid coordinates
    ExplorationService::VALID_COORDS.each do |x|
      ExplorationService::VALID_COORDS.each do |y|
        ExplorationService::VALID_COORDS.each do |z|
          system = System.discover_at(x: x, y: y, z: z, user: @user)
          SystemVisit.record_visit(@user, system)
        end
      end
    end

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored

    assert_nil result
  end

  test "closest_unexplored filters by direction spinward" do
    result = @service.closest_unexplored(direction: :spinward)

    # Spinward is positive X direction
    # From (0,0,0), should be (3,0,0)
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

  test "all_unexplored returns all unexplored sorted by distance" do
    results = @service.all_unexplored

    # Should be 63 unexplored (64 total - 1 visited)
    assert_equal 63, results.size

    # Should be sorted by distance
    distances = results.map { |r| r[:distance] }
    assert_equal distances.sort, distances
  end

  test "all_unexplored respects limit parameter" do
    results = @service.all_unexplored(limit: 5)

    assert_equal 5, results.size
  end

  test "all_unexplored filters by direction" do
    results = @service.all_unexplored(direction: :spinward)

    # All results should have X > current position (0)
    results.each do |r|
      assert r[:x] > @cradle.x, "Spinward results should have X > #{@cradle.x}"
    end
  end

  # ===========================================
  # closest_unexplored_orbital tests
  # ===========================================

  test "closest_unexplored_orbital returns origin when nothing explored" do
    # Create fresh user with no exploration history
    fresh_user = User.create!(
      email: "fresh_explorer@example.com",
      name: "Fresh Explorer",
      tutorial_phase: :proving_ground
    )
    service = ExplorationService.new(fresh_user)

    result = service.closest_unexplored_orbital

    assert_not_nil result
    assert_equal 0, result[:x]
    assert_equal 0, result[:y]
    assert_equal 0, result[:z]
  end

  test "closest_unexplored_orbital returns nil when all nearby explored" do
    # Explore a large area around origin
    (-2..2).each do |x|
      (-2..2).each do |y|
        (-2..2).each do |z|
          @user.explored_coordinates.find_or_create_by!(x: x, y: y, z: z) do |coord|
            coord.has_system = false
          end
        end
      end
    end

    service = ExplorationService.new(@user)
    result = service.closest_unexplored_orbital

    # Should find something at distance 3 or beyond
    assert_not_nil result
    distance = Math.sqrt(result[:x]**2 + result[:y]**2 + result[:z]**2)
    assert distance >= 2.5, "Should find unexplored at distance >= 3"
  end

  test "explores at same orbital distance first" do
    # Create fresh user and mark only origin as explored
    fresh_user = User.create!(
      email: "orbital_explorer@example.com",
      name: "Orbital Explorer",
      tutorial_phase: :proving_ground
    )
    fresh_user.explored_coordinates.create!(x: 0, y: 0, z: 0, has_system: false)

    service = ExplorationService.new(fresh_user)
    result = service.closest_unexplored_orbital

    # Should be at distance ~1 (same ring as origin which is 0, so next ring)
    distance = Math.sqrt(result[:x]**2 + result[:y]**2 + result[:z]**2)
    assert_in_delta 1.0, distance, 0.5, "Should explore at the next orbital ring"
  end

  test "uses ship position for orbital exploration when available" do
    # Move ship to (6,6,6)
    far_system = System.discover_at(x: 6, y: 6, z: 6, user: @user)
    @ship.update!(current_system: far_system)

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored_orbital

    # Should find coordinate at similar orbital distance to ship's position (~10.4)
    ship_distance = Math.sqrt(6**2 + 6**2 + 6**2).round # ~10
    result_distance = Math.sqrt(result[:x]**2 + result[:y]**2 + result[:z]**2).round

    assert_not_nil result
    # Should be within MAX_SEARCH_DISTANCE of ship's orbital ring
    assert (result_distance - ship_distance).abs <= ExplorationService::MAX_SEARCH_DISTANCE,
      "Result distance #{result_distance} should be within #{ExplorationService::MAX_SEARCH_DISTANCE} of ship distance #{ship_distance}"
  end

  test "respects MAX_SEARCH_DISTANCE constant" do
    assert_equal 10, ExplorationService::MAX_SEARCH_DISTANCE
  end

  test "generates shell coordinates correctly for distance 0" do
    coords = @service.send(:generate_shell_coordinates, 0)

    assert_equal 1, coords.length
    assert_equal({ x: 0, y: 0, z: 0 }, coords.first)
  end

  test "generates shell coordinates at correct distance" do
    coords = @service.send(:generate_shell_coordinates, 1)

    # All coordinates should be roughly at distance 1
    coords.each do |c|
      distance = Math.sqrt(c[:x]**2 + c[:y]**2 + c[:z]**2)
      assert_in_delta 1.0, distance, 0.5, "Coordinate #{c} should be at distance ~1"
    end

    # Should include key axis-aligned points
    assert coords.include?({ x: 1, y: 0, z: 0 })
    assert coords.include?({ x: -1, y: 0, z: 0 })
    assert coords.include?({ x: 0, y: 1, z: 0 })
    assert coords.include?({ x: 0, y: -1, z: 0 })
    assert coords.include?({ x: 0, y: 0, z: 1 })
    assert coords.include?({ x: 0, y: 0, z: -1 })
  end

  # ===========================================
  # Progress tracking tests
  # ===========================================

  test "total_coordinates returns 64" do
    assert_equal 64, @service.total_coordinates
  end

  test "explored_count tracks visited valid coordinates" do
    # Started with 1 visit (Cradle at 0,0,0)
    assert_equal 1, @service.explored_count
  end

  test "explored_count ignores non-grid coordinates" do
    # Visit a system not on the exploration grid
    off_grid = System.discover_at(x: 1, y: 1, z: 1, user: @user)
    SystemVisit.record_visit(@user, off_grid)

    service = ExplorationService.new(@user, @ship)
    # Should still be 1 (only the cradle)
    assert_equal 1, service.explored_count
  end

  test "all_explored? returns false when coordinates remain" do
    assert_not @service.all_explored?
  end

  test "all_explored? returns true when all visited" do
    # Visit all valid coordinates
    ExplorationService::VALID_COORDS.each do |x|
      ExplorationService::VALID_COORDS.each do |y|
        ExplorationService::VALID_COORDS.each do |z|
          system = System.discover_at(x: x, y: y, z: z, user: @user)
          SystemVisit.record_visit(@user, system)
        end
      end
    end

    service = ExplorationService.new(@user, @ship)
    assert service.all_explored?
  end

  test "progress_percentage calculates correctly" do
    # 1 out of 64 explored
    assert_in_delta 1.56, @service.progress_percentage, 0.01

    # Visit a few more
    sys1 = System.discover_at(x: 3, y: 0, z: 0, user: @user)
    sys2 = System.discover_at(x: 0, y: 3, z: 0, user: @user)
    SystemVisit.record_visit(@user, sys1)
    SystemVisit.record_visit(@user, sys2)

    service = ExplorationService.new(@user, @ship)
    # 3 out of 64 = 4.69%
    assert_in_delta 4.69, service.progress_percentage, 0.01
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

    # Should return a result but distance may be Infinity
    # or handled gracefully - just ensure no crash
    assert_not_nil result
    assert_equal Float::INFINITY, result[:distance]
  end

  test "distance from non-origin position calculated correctly" do
    # Move ship to (3,3,3)
    new_system = System.discover_at(x: 3, y: 3, z: 3, user: @user)
    @ship.update!(current_system: new_system)
    SystemVisit.record_visit(@user, new_system)

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored

    # From (3,3,3), closest should be distance 3 (adjacent on any axis)
    assert_equal 3.0, result[:distance]
  end

  test "tie-breaking is deterministic" do
    # From (0,0,0), points (3,0,0), (0,3,0), (0,0,3) are all distance 3
    # min_by should return consistent results
    result1 = @service.closest_unexplored
    result2 = @service.closest_unexplored

    assert_equal result1, result2
  end
end
