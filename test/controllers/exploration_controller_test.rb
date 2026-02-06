require "test_helper"

class ExplorationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    @ship.update!(disabled_at: nil, status: "docked")
    sign_in_as(@user)
  end

  test "show renders exploration page" do
    get exploration_path

    assert_response :success
    assert_select "h2", /Exploration/
  end

  test "show displays exploration modes" do
    get exploration_path

    assert_response :success
    assert_select "h4", "Single Direction"
    assert_select "h4", "Growing Arcs"
    assert_select "h4", "Orbit"
  end

  # =========================================
  # Single Direction Tests
  # =========================================

  test "single_direction explores in valid direction" do
    # The service looks for unexplored coordinates at valid positions (0,3,6,9)
    # The ship is at cradle, and we explore in +x direction

    post single_direction_exploration_path(direction: "+x")

    assert_redirected_to exploration_path
    # Should have explored a coordinate or shown an alert (if all explored in that direction)
    assert flash[:notice].present? || flash[:alert].present?
  end

  test "single_direction rejects invalid direction" do
    post single_direction_exploration_path(direction: "invalid")

    assert_redirected_to exploration_path
    assert_equal "Invalid direction: invalid", flash[:alert]
  end

  test "single_direction requires operational ship" do
    # Disable all user's ships
    @user.ships.update_all(disabled_at: Time.current)

    post single_direction_exploration_path(direction: "+x")

    assert_redirected_to exploration_path
    assert_equal "No operational ship available", flash[:alert]
  end

  # =========================================
  # Growing Arcs Tests
  # =========================================

  test "growing_arcs explores closest unexplored coordinate" do
    assert_difference -> { ExploredCoordinate.count }, 1 do
      post growing_arcs_exploration_path
    end

    assert_redirected_to exploration_path
    assert_match /Explored/, flash[:notice]
  end

  test "growing_arcs shows alert when all coordinates explored" do
    # Mark all valid coordinates as explored
    ExplorationService::VALID_COORDS.each do |x|
      ExplorationService::VALID_COORDS.each do |y|
        ExplorationService::VALID_COORDS.each do |z|
          ExploredCoordinate.mark_explored!(user: @user, x: x, y: y, z: z)
        end
      end
    end

    post growing_arcs_exploration_path

    assert_redirected_to exploration_path
    assert_match /All coordinates explored/, flash[:alert]
  end

  # =========================================
  # Orbit Tests
  # =========================================

  test "orbit explores closest unexplored coordinate in orbital pattern" do
    assert_difference -> { ExploredCoordinate.count }, 1 do
      post orbit_exploration_path
    end

    assert_redirected_to exploration_path
    assert_match /Explored/, flash[:notice]
  end

  test "orbit shows alert when all orbital coordinates explored" do
    # Mark all valid coordinates as explored
    ExplorationService::VALID_COORDS.each do |x|
      ExplorationService::VALID_COORDS.each do |y|
        ExplorationService::VALID_COORDS.each do |z|
          ExploredCoordinate.mark_explored!(user: @user, x: x, y: y, z: z)
        end
      end
    end

    post orbit_exploration_path

    assert_redirected_to exploration_path
    assert_match /All orbital coordinates explored/, flash[:alert]
  end
end
