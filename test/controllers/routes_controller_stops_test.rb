# frozen_string_literal: true

require "test_helper"

class RoutesControllerStopsTest < ActionDispatch::IntegrationTest
  # ===========================================
  # Task: stellarb-vsx.18 - Routes for stop management
  # ===========================================

  setup do
    @user = users(:pilot)
    @route = routes(:trade_route)
    sign_in_as(@user)
  end

  # ===========================================
  # edit_stops - Enter edit mode
  # ===========================================

  test "GET edit_stops returns edit mode view" do
    get edit_stops_route_path(@route)
    assert_response :success
  end

  # ===========================================
  # add_stop - Add a new stop
  # ===========================================

  test "POST add_stop creates a new stop" do
    system = systems(:cradle)
    @route.update!(stops: [])

    assert_difference -> { @route.reload.stops.size }, 1 do
      post route_stops_path(@route), params: {
        stop: { system_id: system.id, system: system.name }
      }, as: :turbo_stream
    end

    assert_response :success
    new_stop = @route.stops.last
    assert_equal system.id, new_stop["system_id"]
    assert_equal [], new_stop["intents"]
  end

  test "POST add_stop redirects on HTML request" do
    system = systems(:cradle)
    @route.update!(stops: [])

    post route_stops_path(@route), params: {
      stop: { system_id: system.id, system: system.name }
    }

    assert_redirected_to edit_stops_route_path(@route)
  end

  # ===========================================
  # remove_stop - Remove a stop
  # ===========================================

  test "DELETE remove_stop removes the stop at index" do
    @route.update!(stops: [
      { "system_id" => 1, "system" => "A", "intents" => [] },
      { "system_id" => 2, "system" => "B", "intents" => [] }
    ])

    assert_difference -> { @route.reload.stops.size }, -1 do
      delete route_stop_path(@route, 0), as: :turbo_stream
    end

    assert_response :success
    assert_equal "B", @route.stops.first["system"]
  end

  # ===========================================
  # reorder_stop - Change stop position
  # ===========================================

  test "PATCH reorder_stop moves stop to new position" do
    @route.update!(stops: [
      { "system_id" => 1, "system" => "A", "intents" => [] },
      { "system_id" => 2, "system" => "B", "intents" => [] },
      { "system_id" => 3, "system" => "C", "intents" => [] }
    ])

    patch reorder_route_stop_path(@route, 0), params: { to: 2 }, as: :turbo_stream

    assert_response :success
    @route.reload
    assert_equal "B", @route.stops[0]["system"]
    assert_equal "C", @route.stops[1]["system"]
    assert_equal "A", @route.stops[2]["system"]
  end

  # ===========================================
  # update_stop - Update stop system
  # ===========================================

  test "PATCH update_stop changes stop system" do
    @route.update!(stops: [
      { "system_id" => 1, "system" => "Old System", "intents" => [] }
    ])
    new_system = systems(:alpha_centauri)

    patch route_stop_path(@route, 0), params: {
      stop: { system_id: new_system.id, system: new_system.name }
    }, as: :turbo_stream

    assert_response :success
    @route.reload
    assert_equal new_system.id, @route.stops[0]["system_id"]
    assert_equal new_system.name, @route.stops[0]["system"]
  end
end
