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
end
