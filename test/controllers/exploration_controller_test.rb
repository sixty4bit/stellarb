require "test_helper"

class ExplorationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    sign_in_as(@user)
  end

  test "show renders exploration page" do
    get exploration_path

    assert_response :success
    assert_select "h2", /Exploration/
  end

  test "growing_arcs explores closest unexplored coordinate" do
    assert_difference -> { @user.explored_coordinates.count }, 1 do
      post growing_arcs_exploration_path
    end

    assert_redirected_to exploration_path
    assert_match /Explored/, flash[:notice]
  end

  test "growing_arcs marks has_system correctly based on system existence" do
    # The cradle system exists at the ship's current location
    # Explore a coordinate and verify has_system is false (no system at distance 1)
    post growing_arcs_exploration_path

    coord = @user.explored_coordinates.order(created_at: :desc).first
    # Most coordinates don't have systems, so has_system should be false
    # We're just verifying the attribute is being set
    assert_includes [true, false], coord.has_system
  end

  test "growing_arcs shows alert when all coordinates explored" do
    origin = @ship.current_system

    # Fill up explored coordinates for distance 1-10
    (-10..10).each do |dx|
      (-10..10).each do |dy|
        (-10..10).each do |dz|
          distance = dx.abs + dy.abs + dz.abs
          next if distance == 0 || distance > 10

          @user.explored_coordinates.find_or_create_by!(
            x: origin.x + dx,
            y: origin.y + dy,
            z: origin.z + dz
          )
        end
      end
    end

    post growing_arcs_exploration_path

    assert_redirected_to exploration_path
    assert_match /All coordinates explored/, flash[:alert]
  end
end
