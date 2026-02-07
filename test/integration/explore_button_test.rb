# frozen_string_literal: true

require "test_helper"

class ExploreButtonTest < ActionDispatch::IntegrationTest
  test "logged-in user with operational ship sees explore button" do
    sign_in_as(users(:pilot))
    get inbox_index_path

    assert_response :success
    assert_select "form[action=?]", growing_arcs_exploration_path
    assert_select "form button", /🔭/
  end

  test "logged-in user without ships does not see explore button" do
    sign_in_as(users(:one))
    get inbox_index_path

    assert_response :success
    assert_select "form[action=?]", growing_arcs_exploration_path, count: 0
  end
end
