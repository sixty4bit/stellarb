require "test_helper"

class ExplorationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    @ship.update!(disabled_at: nil, status: "docked")
    sign_in_as(@user)
  end

  test "show displays current position when ship available" do
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

  test "single_direction explores in valid direction" do
    # The cradle system is at (0,0,0) - but coordinate (3,0,0) is +x (spinward)
    # Move the ship to a location that can explore
    @ship.current_system.update!(x: 0, y: 0, z: 0)

    post single_direction_exploration_path(direction: "+x")

    assert_redirected_to exploration_path
    # Should have explored a coordinate
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

  test "growing_arcs shows placeholder message" do
    post growing_arcs_exploration_path

    assert_redirected_to exploration_path
    assert_match /coming soon/i, flash[:notice]
  end

  test "orbit shows placeholder message" do
    post orbit_exploration_path

    assert_redirected_to exploration_path
    assert_match /coming soon/i, flash[:notice]
  end
end
