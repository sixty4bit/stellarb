# frozen_string_literal: true

require "test_helper"

class RouteIntentsControllerTest < ActionDispatch::IntegrationTest
  # ===========================================
  # Task: stellarb-vsx.19 - Routes for intent management
  # ===========================================

  setup do
    @user = users(:pilot)
    @route = routes(:trade_route)
    sign_in_as(@user)
  end

  # ===========================================
  # add_intent - Add intent to a stop
  # ===========================================

  test "POST add_intent creates a new intent on the stop" do
    @route.update!(stops: [
      { "system_id" => 1, "system" => "A", "intents" => [] }
    ])

    post route_stop_intents_path(@route, 0), params: {
      intent: { type: "buy", commodity: "ore", quantity: 100, max_price: 150 }
    }, as: :turbo_stream

    assert_response :success
    @route.reload
    assert_equal 1, @route.stops[0]["intents"].size
    intent = @route.stops[0]["intents"][0]
    assert_equal "buy", intent["type"]
    assert_equal "ore", intent["commodity"]
    assert_equal 100, intent["quantity"]
    assert_equal 150, intent["max_price"]
  end

  test "POST add_intent with sell creates intent with min_price" do
    @route.update!(stops: [
      { "system_id" => 1, "system" => "A", "intents" => [] }
    ])

    post route_stop_intents_path(@route, 0), params: {
      intent: { type: "sell", commodity: "water", quantity: 50, min_price: 80 }
    }, as: :turbo_stream

    assert_response :success
    @route.reload
    intent = @route.stops[0]["intents"][0]
    assert_equal "sell", intent["type"]
    assert_equal 80, intent["min_price"]
  end

  # ===========================================
  # remove_intent - Remove intent from a stop
  # ===========================================

  test "DELETE remove_intent removes the intent at index" do
    @route.update!(stops: [
      {
        "system_id" => 1,
        "system" => "A",
        "intents" => [
          { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 },
          { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
        ]
      }
    ])

    assert_difference -> { @route.reload.stops[0]["intents"].size }, -1 do
      delete route_stop_intent_path(@route, 0, 0), as: :turbo_stream
    end

    assert_response :success
    assert_equal "sell", @route.stops[0]["intents"][0]["type"]
  end

  # ===========================================
  # update_intent - Update intent properties
  # ===========================================

  test "PATCH update_intent changes intent properties" do
    @route.update!(stops: [
      {
        "system_id" => 1,
        "system" => "A",
        "intents" => [
          { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
        ]
      }
    ])

    patch route_stop_intent_path(@route, 0, 0), params: {
      intent: { quantity: 200, max_price: 175 }
    }, as: :turbo_stream

    assert_response :success
    @route.reload
    intent = @route.stops[0]["intents"][0]
    assert_equal 200, intent["quantity"]
    assert_equal 175, intent["max_price"]
    # Unchanged properties
    assert_equal "buy", intent["type"]
    assert_equal "ore", intent["commodity"]
  end

  test "PATCH update_intent can change commodity" do
    @route.update!(stops: [
      {
        "system_id" => 1,
        "system" => "A",
        "intents" => [
          { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
        ]
      }
    ])

    patch route_stop_intent_path(@route, 0, 0), params: {
      intent: { commodity: "gold" }
    }, as: :turbo_stream

    assert_response :success
    @route.reload
    assert_equal "gold", @route.stops[0]["intents"][0]["commodity"]
  end
end
