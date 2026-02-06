require "test_helper"

class ExplorationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
  end

  test "closest_unexplored returns coordinate at distance 1 first" do
    service = ExplorationService.new(@user, @ship)
    origin = @ship.current_system

    result = service.closest_unexplored

    assert_not_nil result
    distance = (result[:x] - origin.x).abs + (result[:y] - origin.y).abs + (result[:z] - origin.z).abs
    assert_equal 1, distance, "First unexplored should be at distance 1"
  end

  test "closest_unexplored skips explored coordinates" do
    origin = @ship.current_system

    # Explore all coordinates at distance 1
    [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]].each do |dx, dy, dz|
      @user.explored_coordinates.create!(
        x: origin.x + dx,
        y: origin.y + dy,
        z: origin.z + dz
      )
    end

    service = ExplorationService.new(@user, @ship)
    result = service.closest_unexplored

    assert_not_nil result
    distance = (result[:x] - origin.x).abs + (result[:y] - origin.y).abs + (result[:z] - origin.z).abs
    assert_equal 2, distance, "Should return distance 2 when distance 1 is explored"
  end

  test "closest_unexplored returns nil when all explored" do
    origin = @ship.current_system

    # Explore everything within radius 10
    (-10..10).each do |dx|
      (-10..10).each do |dy|
        (-10..10).each do |dz|
          distance = dx.abs + dy.abs + dz.abs
          next if distance == 0 || distance > 10

          @user.explored_coordinates.create!(
            x: origin.x + dx,
            y: origin.y + dy,
            z: origin.z + dz
          )
        end
      end
    end

    service = ExplorationService.new(@user, @ship)

    assert_nil service.closest_unexplored
  end

  test "closest_unexplored uses ship location_x when no current_system" do
    @ship.update!(current_system: nil, location_x: 5, location_y: 5, location_z: 5)
    service = ExplorationService.new(@user, @ship)

    result = service.closest_unexplored

    assert_not_nil result
    distance = (result[:x] - 5).abs + (result[:y] - 5).abs + (result[:z] - 5).abs
    assert_equal 1, distance
  end
end
