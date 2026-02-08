# frozen_string_literal: true

require "test_helper"

class ShipsControllerActionButtonsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @user.update!(profile_completed_at: Time.current)
    @ship = ships(:hauler)
    sign_in_as(@user)
  end

  test "ship show has navigation link with real path" do
    get ship_path(@ship)
    assert_response :success
    assert_select "a[href*='navigation']", text: /Set Navigation/
  end

  test "ship show has assign to route link with real path" do
    get ship_path(@ship)
    assert_response :success
    assert_select "a[href*='routes']", text: /Assign to Route/
  end

  test "ship show has manage cargo link to market when docked" do
    # Ship should be docked at a system
    assert @ship.current_system.present?, "Ship fixture should have a current_system"
    get ship_path(@ship)
    assert_response :success
    assert_select "a[href*='market']", text: /Manage Cargo/
  end

  test "ship show action buttons do not link to hash" do
    get ship_path(@ship)
    assert_response :success
    # None of the action buttons should link to "#" (except disabled ones)
    assert_select "a[href='#']", text: /Set Navigation/, count: 0
    assert_select "a[href='#']", text: /Assign to Route/, count: 0
  end
end
