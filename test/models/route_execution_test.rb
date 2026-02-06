# frozen_string_literal: true

require "test_helper"

class RouteExecutionTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-vsx.28-30 - Route execution with price checking
  # ===========================================

  setup do
    @user = User.create!(name: "Test Trader", email: "trader#{SecureRandom.hex(4)}@test.com")
    @system = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @ship = @user.ships.create!(
      name: "Trade Ship",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      current_system: @system
    )
    @route = @user.routes.create!(
      name: "Test Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @system.id,
          "system" => @system.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 },
            { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
          ]
        }
      ]
    )
  end

  # ===========================================
  # Price checking
  # ===========================================

  test "intent_should_execute? returns true when buy price is below max" do
    intent = { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
    current_price = 100

    assert @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns false when buy price exceeds max" do
    intent = { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
    current_price = 200

    refute @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns true when buy price equals max" do
    intent = { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
    current_price = 150

    assert @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns true when sell price is above min" do
    intent = { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
    current_price = 100

    assert @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns false when sell price is below min" do
    intent = { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
    current_price = 50

    refute @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns true when sell price equals min" do
    intent = { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
    current_price = 80

    assert @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns true for load intent below max_price" do
    intent = { "type" => "load", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
    current_price = 100

    assert @route.intent_should_execute?(intent, current_price)
  end

  test "intent_should_execute? returns true for unload intent above min_price" do
    intent = { "type" => "unload", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
    current_price = 100

    assert @route.intent_should_execute?(intent, current_price)
  end

  # ===========================================
  # Skip + notify
  # ===========================================

  test "skip_and_notify_intent creates inbox message" do
    intent = { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
    current_price = 200

    assert_difference -> { @user.messages.count }, 1 do
      @route.skip_and_notify_intent(intent, current_price, @system)
    end

    message = @user.messages.last
    assert_includes message.title, "skipped"
    assert_includes message.body, "ore"
    assert_includes message.body, "200"
    assert_includes message.body, "150"
    assert_equal "route", message.category
  end

  test "skip_and_notify_intent message is not urgent" do
    intent = { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }

    @route.skip_and_notify_intent(intent, 200, @system)

    message = @user.messages.last
    refute message.urgent
  end
end
