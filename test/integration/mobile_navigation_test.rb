# frozen_string_literal: true

require "test_helper"

class MobileNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "layout renders mobile top bar with hamburger button" do
    sign_in_as(@user)
    get inbox_index_path

    assert_response :success
    assert_select "[data-controller~='mobile-menu']"
    assert_select "[data-action='click->mobile-menu#toggle']"
  end

  test "layout renders player name and credits in mobile top bar" do
    sign_in_as(@user)
    get inbox_index_path

    assert_response :success
    assert_select ".mobile-top-bar", /Credits/
  end

  test "layout renders unread badge in mobile top bar" do
    sign_in_as(@user)
    get inbox_index_path

    assert_response :success
    assert_select ".mobile-top-bar #mobile_inbox_unread_badge"
  end

  test "sidebar is hidden on mobile via CSS classes" do
    sign_in_as(@user)
    get inbox_index_path

    assert_response :success
    # The sidebar wrapper should have hidden md:block classes
    assert_select "div.hidden.md\\:block"
  end

  test "mobile drawer exists with proper data attributes" do
    sign_in_as(@user)
    get inbox_index_path

    assert_response :success
    assert_select "[data-mobile-menu-target='drawer']"
    assert_select "[data-mobile-menu-target='backdrop']"
  end
end
