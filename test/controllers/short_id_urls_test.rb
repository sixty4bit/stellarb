# frozen_string_literal: true

require "test_helper"

class ShortIdUrlsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
  end

  test "building to_param returns short_id" do
    building = buildings(:mining_facility)
    assert_equal building.short_id, building.to_param
  end

  test "route to_param returns short_id" do
    route = routes(:trade_route)
    assert_equal route.short_id, route.to_param
  end

  test "user to_param returns short_id" do
    assert_equal @user.short_id, @user.to_param
  end

  test "building show works with short_id URL" do
    building = buildings(:mining_facility)
    get "/buildings/#{building.short_id}"
    assert_response :success
  end

  test "route show works with short_id URL" do
    route = routes(:trade_route)
    get "/routes/#{route.short_id}"
    assert_response :success
  end
end
