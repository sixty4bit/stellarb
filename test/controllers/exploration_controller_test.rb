require "test_helper"

class ExplorationControllerTest < ActionDispatch::IntegrationTest
  def create_system(name:, short_id:, x:, y:, z:)
    System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
  end

  setup do
    @user = users(:pilot)
    # Need a system within exploration coord range (-9..9)
    @origin = System.find_by(x: 0, y: 0, z: 0) || create_system(name: "Origin", short_id: "sy-org", x: 0, y: 0, z: 0)
    @ship = ships(:hauler)
    @ship.update_columns(current_system_id: @origin.id, location_x: 0, location_y: 0, location_z: 0, fuel: 100.0, status: "docked")
    # Mark origin as explored
    ExploredCoordinate.mark_explored!(user: @user, x: 0, y: 0, z: 0, has_system: true)
    sign_in_as(@user)
  end

  test "show renders exploration page" do
    get exploration_path
    assert_response :success
  end

  test "single_direction initiates ship travel" do
    post single_direction_exploration_path, params: { direction: "+x" }
    assert_redirected_to exploration_path
    @ship.reload
    assert_equal "in_transit", @ship.status
  end

  test "single_direction rejects in-transit ship" do
    @ship.update_columns(status: "in_transit", arrival_at: 5.minutes.from_now)
    post single_direction_exploration_path, params: { direction: "+x" }
    assert_redirected_to exploration_path
    assert_match /already in transit/i, flash[:alert]
  end

  test "single_direction rejects invalid direction" do
    post single_direction_exploration_path, params: { direction: "invalid" }
    assert_redirected_to exploration_path
    assert_match /Invalid direction/i, flash[:alert]
  end
end
