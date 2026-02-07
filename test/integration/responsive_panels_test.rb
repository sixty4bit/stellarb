require "test_helper"

class ResponsivePanelsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    sign_in_as(@user)
  end

  test "ships show page renders with responsive classes" do
    get ship_path(@ship)
    assert_response :success
    assert_select "turbo-frame#content_panel"
    assert_match(/sm:grid-cols-/, response.body)
    assert_match(/sm:p-/, response.body)
  end

  test "ships trading page renders" do
    get trading_ships_path
    assert_response :success
    assert_select "turbo-frame#content_panel"
  end

  test "ships combat page renders" do
    get combat_ships_path
    assert_response :success
    assert_select "turbo-frame#content_panel"
  end

  test "navigation index page renders" do
    get navigation_index_path
    assert_response :success
    assert_select "turbo-frame#content_panel"
  end

  test "exploration show page renders" do
    get exploration_path
    assert_response :success
    assert_select "turbo-frame#content_panel"
  end
end
