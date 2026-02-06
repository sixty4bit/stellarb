# frozen_string_literal: true

require "test_helper"

class RouteIntentsTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-vsx.16 - Stops/intents JSONB structure
  # ===========================================

  setup do
    @user = User.create!(name: "Test Trader", email: "trader#{SecureRandom.hex(4)}@test.com")
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @other_system = System.discover_at(x: 10, y: 10, z: 10, user: @user)
    @ship = @user.ships.create!(
      name: "Trade Ship",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      current_system: @cradle
    )
  end

  # ===========================================
  # New intents structure
  # ===========================================

  test "route supports new intents structure with multiple intents per stop" do
    route = @user.routes.create!(
      name: "Multi-intent Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 },
            { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
          ]
        },
        {
          "system_id" => @other_system.id,
          "system" => @other_system.name,
          "intents" => [
            { "type" => "sell", "commodity" => "ore", "quantity" => 100, "min_price" => 200 }
          ]
        }
      ]
    )

    assert_equal 2, route.stops.size
    assert_equal 2, route.stops[0]["intents"].size
    assert_equal "buy", route.stops[0]["intents"][0]["type"]
    assert_equal 150, route.stops[0]["intents"][0]["max_price"]
  end

  test "route#intents_at returns intents for a specific stop" do
    route = @user.routes.create!(
      name: "Intent Test",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
          ]
        }
      ]
    )

    intents = route.intents_at(0)
    assert_equal 1, intents.size
    assert_equal "ore", intents[0]["commodity"]
  end

  test "route#intents_at returns empty array for invalid index" do
    route = @user.routes.create!(name: "Test", ship: @ship, stops: [])
    assert_equal [], route.intents_at(0)
    assert_equal [], route.intents_at(99)
  end

  test "route#add_stop adds a new stop with empty intents" do
    route = @user.routes.create!(name: "Test", ship: @ship, stops: [])
    
    route.add_stop(system_id: @cradle.id, system: @cradle.name)
    route.save!
    route.reload

    assert_equal 1, route.stops.size
    assert_equal @cradle.id, route.stops[0]["system_id"]
    assert_equal [], route.stops[0]["intents"]
  end

  test "route#remove_stop removes stop at index" do
    route = @user.routes.create!(
      name: "Test",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "system" => @cradle.name, "intents" => [] },
        { "system_id" => @other_system.id, "system" => @other_system.name, "intents" => [] }
      ]
    )

    route.remove_stop(0)
    route.save!
    route.reload

    assert_equal 1, route.stops.size
    assert_equal @other_system.id, route.stops[0]["system_id"]
  end

  test "route#reorder_stops moves stop from one position to another" do
    route = @user.routes.create!(
      name: "Test",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "system" => "A", "intents" => [] },
        { "system_id" => @other_system.id, "system" => "B", "intents" => [] }
      ]
    )

    route.reorder_stop(from: 0, to: 1)
    route.save!
    route.reload

    assert_equal "B", route.stops[0]["system"]
    assert_equal "A", route.stops[1]["system"]
  end

  test "route#add_intent adds intent to stop" do
    route = @user.routes.create!(
      name: "Test",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "system" => @cradle.name, "intents" => [] }
      ]
    )

    route.add_intent(stop_index: 0, type: "buy", commodity: "ore", quantity: 100, max_price: 150)
    route.save!
    route.reload

    assert_equal 1, route.stops[0]["intents"].size
    assert_equal "buy", route.stops[0]["intents"][0]["type"]
    assert_equal 150, route.stops[0]["intents"][0]["max_price"]
  end

  test "route#remove_intent removes intent from stop" do
    route = @user.routes.create!(
      name: "Test",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 },
            { "type" => "sell", "commodity" => "water", "quantity" => 50, "min_price" => 80 }
          ]
        }
      ]
    )

    route.remove_intent(stop_index: 0, intent_index: 0)
    route.save!
    route.reload

    assert_equal 1, route.stops[0]["intents"].size
    assert_equal "sell", route.stops[0]["intents"][0]["type"]
  end

  test "route#update_intent updates intent properties" do
    route = @user.routes.create!(
      name: "Test",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
          ]
        }
      ]
    )

    route.update_intent(stop_index: 0, intent_index: 0, quantity: 200, max_price: 175)
    route.save!
    route.reload

    intent = route.stops[0]["intents"][0]
    assert_equal 200, intent["quantity"]
    assert_equal 175, intent["max_price"]
    assert_equal "buy", intent["type"]  # unchanged
    assert_equal "ore", intent["commodity"]  # unchanged
  end

  # ===========================================
  # Backward compatibility with old structure
  # ===========================================

  test "route.has_stops? works with new intents structure" do
    route = @user.routes.create!(
      name: "Test",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "system" => @cradle.name, "intents" => [] }
      ]
    )

    assert route.has_stops?
  end

  test "within_cradle? works with new intents structure" do
    route = @user.routes.create!(
      name: "Cradle Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "system" => @cradle.name, "intents" => [] }
      ]
    )

    assert route.within_cradle?
  end

  # ===========================================
  # Task: stellarb-vsx.17 - Price limit validations
  # ===========================================

  test "route validates buy intents require max_price" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100 }  # missing max_price
          ]
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("max_price") }
  end

  test "route validates load intents require max_price" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "load", "commodity" => "ore", "quantity" => 100 }  # missing max_price
          ]
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("max_price") }
  end

  test "route validates sell intents require min_price" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "sell", "commodity" => "ore", "quantity" => 100 }  # missing min_price
          ]
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("min_price") }
  end

  test "route validates unload intents require min_price" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "unload", "commodity" => "ore", "quantity" => 100 }  # missing min_price
          ]
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("min_price") }
  end

  test "route is valid when buy intent has max_price" do
    route = @user.routes.build(
      name: "Valid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "quantity" => 100, "max_price" => 150 }
          ]
        }
      ]
    )

    assert route.valid?
  end

  test "route is valid when sell intent has min_price" do
    route = @user.routes.build(
      name: "Valid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "sell", "commodity" => "ore", "quantity" => 100, "min_price" => 80 }
          ]
        }
      ]
    )

    assert route.valid?
  end

  test "route validates intents require commodity" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "quantity" => 100, "max_price" => 150 }  # missing commodity
          ]
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("commodity") }
  end

  test "route validates intents require quantity" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system_id" => @cradle.id,
          "system" => @cradle.name,
          "intents" => [
            { "type" => "buy", "commodity" => "ore", "max_price" => 150 }  # missing quantity
          ]
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("quantity") }
  end

  test "route validates stops require system_id" do
    route = @user.routes.build(
      name: "Invalid Route",
      ship: @ship,
      stops: [
        {
          "system" => "Alpha",  # missing system_id
          "intents" => []
        }
      ]
    )

    refute route.valid?
    assert route.errors[:stops].any? { |e| e.include?("system_id") }
  end
end
