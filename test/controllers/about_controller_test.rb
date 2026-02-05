# frozen_string_literal: true

require "test_helper"

class AboutControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
  end

  # Screen 17: About
  test "index renders about page" do
    get about_path
    assert_response :success
    assert_select "h1", text: /About/
  end

  test "index shows player name" do
    get about_path
    assert_response :success
    assert_select "*", text: /Test Pilot/
  end

  test "index shows credits" do
    get about_path
    assert_response :success
    assert_select "*", text: /Credits/
  end

  test "index shows playtime" do
    get about_path
    assert_response :success
    assert_select "*", text: /Play Time/i
  end

  test "index shows fleet statistics" do
    get about_path
    assert_response :success
    assert_select "*", text: /Fleet Statistics/i
  end

  test "index shows keyboard shortcuts reference" do
    get about_path
    assert_response :success
    assert_select "*", text: /keyboard shortcuts/i
  end
end
