# frozen_string_literal: true

require "test_helper"

class RoutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @route = routes(:trade_route)
    sign_in_as(@user)
  end

  # Screen 11: Routes List (Trading)
  test "index renders routes list" do
    get routes_path
    assert_response :success
    assert_select "h1", text: /Routes/i
  end

  test "index shows user routes" do
    get routes_path
    assert_response :success
    assert_select "a", text: /Cradle Supply Run/i
  end

  test "index displays route status" do
    get routes_path
    assert_response :success
    assert_select "*", text: /ACTIVE/i
  end

  test "index shows profit information" do
    get routes_path
    assert_response :success
    assert_select "*", text: /profit/i
  end

  test "index shows loop count" do
    get routes_path
    assert_response :success
    assert_select "*", text: /15/
  end

  test "index highlights paused routes" do
    get routes_path
    assert_response :success
    assert_select "*", text: /PAUSED/i
  end

  # Screen 12: Route Detail
  test "show renders route detail" do
    get route_path(@route)
    assert_response :success
    assert_select "h1", text: /Cradle Supply Run/i
  end

  test "show displays route stops" do
    get route_path(@route)
    assert_response :success
    # Should show buy/sell actions
    assert_select "*", text: /buy/i
  end

  test "show displays assigned ship" do
    get route_path(@route)
    assert_response :success
    assert_select "*", text: /Stellar Hauler/i
  end

  test "show has pause/resume controls" do
    get route_path(@route)
    assert_response :success
    assert_select "a, button", text: /Pause/i
  end

  test "show has back to routes link" do
    get route_path(@route)
    assert_response :success
    assert_select "a[href='#{routes_path}']"
  end

  test "new renders route form" do
    get new_route_path
    assert_response :success
    assert_select "form"
  end
end
