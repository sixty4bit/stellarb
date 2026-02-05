# frozen_string_literal: true

require "test_helper"

class NavigationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
  end

  test "index renders navigation view" do
    get navigation_index_path
    assert_response :success
    assert_select "h2", text: /Navigation/
  end

  test "index shows current location section" do
    get navigation_index_path
    assert_response :success
    assert_select "h3", text: /Current Location/
  end

  test "index shows nearby systems section" do
    get navigation_index_path
    assert_response :success
    assert_select "h3", text: /Nearby Systems/
  end

  test "index shows active routes section" do
    get navigation_index_path
    assert_response :success
    assert_select "h3", text: /Active Routes/
  end
end
