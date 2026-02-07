# frozen_string_literal: true

require "test_helper"

class KeyboardNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
  end

  # Test that keyboard navigation controller is connected
  test "layout includes keyboard navigation controller" do
    get root_path
    assert_response :success
    assert_select "[data-controller~='keyboard-navigation']"
  end

  test "layout includes keyboard help modal" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help"
  end

  test "keyboard help shows j/k navigation" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help", text: /j\/k/
    assert_select "#keyboard-help", text: /Navigate up\/down/
  end

  test "keyboard help shows Enter action" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help", text: /Enter/
    assert_select "#keyboard-help", text: /Select/
  end

  test "keyboard help shows Esc/q action" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help", text: /Esc\/q/
    assert_select "#keyboard-help", text: /Go back/
  end

  test "keyboard help shows H for home" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help dt", text: "H"
    assert_select "#keyboard-help", text: /Home/
  end

  test "keyboard help shows ? for help" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help dt", text: "?"
    assert_select "#keyboard-help", text: /Show this help/
  end

  test "keyboard help modal is hidden by default" do
    get root_path
    assert_response :success
    assert_select "#keyboard-help.hidden"
  end

  # Verify controller JS file exists
  test "keyboard navigation controller exists" do
    controller_path = Rails.root.join('app/javascript/controllers/keyboard_navigation_controller.js')
    assert File.exist?(controller_path), "Keyboard navigation controller should exist"
  end

  # Test that content pages work with Turbo Frames
  test "content panel uses turbo frames" do
    get root_path
    assert_response :success
    assert_select "turbo-frame#content_panel"
  end
end
