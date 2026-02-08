# frozen_string_literal: true

require "test_helper"

class ShipsRepairControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    @ship.ship_attributes["hull_points"] = 50
    @ship.save!
    sign_in_as(@user)
  end

  test "repair action restores hull and redirects" do
    post repair_ship_path(@ship)
    assert_redirected_to ship_path(@ship)
    follow_redirect!
    assert_match /repaired/, flash[:notice]
  end

  test "repair action fails when not docked" do
    @ship.update!(status: "in_transit")
    post repair_ship_path(@ship)
    assert_redirected_to ship_path(@ship)
    follow_redirect!
    assert_match /docked/, flash[:alert]
  end
end
