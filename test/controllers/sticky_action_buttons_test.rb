# frozen_string_literal: true

require "test_helper"

class StickyActionButtonsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @user.update!(profile_completed_at: Time.current)
    @ship = ships(:hauler)
    @system = @ship.current_system
    sign_in_as(@user)
  end

  test "ship show has sticky action bar" do
    get ship_path(@ship)
    assert_response :success
    assert_select "div.fixed.bottom-0.bg-blue-950.border-t.border-blue-700"
  end

  test "system show has sticky action bar" do
    # Visit the system first
    SystemVisit.find_or_create_by!(user: @user, system: @system) do |sv|
      sv.last_visited_at = Time.current
    end
    get system_path(@system)
    assert_response :success
    assert_select "div.fixed.bottom-0.bg-blue-950.border-t.border-blue-700"
  end

  test "ship show has spacer for sticky bar" do
    get ship_path(@ship)
    assert_response :success
    assert_select "div.pb-24"
  end
end
