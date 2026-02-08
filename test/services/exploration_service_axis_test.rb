require "test_helper"

class ExplorationServiceAxisTest < ActiveSupport::TestCase
  def create_system(name:, short_id:, x:, y:, z:)
    System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
  end

  setup do
    @user = users(:one)
    # Create a system at (0,0,0) which is in the COORD range (-9..9)
    @origin = System.find_by(x: 0, y: 0, z: 0) || create_system(name: "Origin", short_id: "sy-org", x: 0, y: 0, z: 0)
    @ship = ships(:hauler)
    @ship.update_columns(current_system_id: @origin.id, location_x: 0, location_y: 0, location_z: 0)
    # Mark (0,0,0) as explored
    ExploredCoordinate.mark_explored!(user: @user, x: 0, y: 0, z: 0, has_system: true)
    SystemVisit.find_or_create_by!(user: @user, system: @origin) do |sv|
      sv.first_visited_at = Time.current
      sv.last_visited_at = Time.current
    end
    @service = ExplorationService.new(@user, @ship)
  end

  test "+X direction constrains y and z to match current position" do
    target = @service.closest_unexplored(direction: :spinward)
    assert_not_nil target, "Should find unexplored coord in +X"
    assert_equal 0, target[:y], "Y should match ship position"
    assert_equal 0, target[:z], "Z should match ship position"
    assert target[:x] > 0, "X should be positive"
  end

  test "-X direction constrains y and z to match current position" do
    target = @service.closest_unexplored(direction: :antispinward)
    assert_not_nil target
    assert_equal 0, target[:y]
    assert_equal 0, target[:z]
    assert target[:x] < 0
  end

  test "+Y direction constrains x and z to match current position" do
    target = @service.closest_unexplored(direction: :north)
    assert_not_nil target
    assert_equal 0, target[:x]
    assert_equal 0, target[:z]
    assert target[:y] > 0
  end

  test "-Y direction constrains x and z to match current position" do
    target = @service.closest_unexplored(direction: :south)
    assert_not_nil target
    assert_equal 0, target[:x]
    assert_equal 0, target[:z]
    assert target[:y] < 0
  end

  test "+Z direction constrains x and y to match current position" do
    target = @service.closest_unexplored(direction: :up)
    assert_not_nil target
    assert_equal 0, target[:x]
    assert_equal 0, target[:y]
    assert target[:z] > 0
  end

  test "-Z direction constrains x and y to match current position" do
    target = @service.closest_unexplored(direction: :down)
    assert_not_nil target
    assert_equal 0, target[:x]
    assert_equal 0, target[:y]
    assert target[:z] < 0
  end

  test "does not return off-axis results for single direction" do
    # Explore (1,0,0), then next +X should be (2,0,0), not (1,1,0)
    ExploredCoordinate.mark_explored!(user: @user, x: 1, y: 0, z: 0, has_system: false)
    target = @service.closest_unexplored(direction: :spinward)
    assert_not_nil target
    assert_equal 2, target[:x]
    assert_equal 0, target[:y]
    assert_equal 0, target[:z]
  end
end
