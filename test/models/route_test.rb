# frozen_string_literal: true

require "test_helper"

class RouteTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-0ap - Route model for automated trading
  # ===========================================

  setup do
    @user = User.create!(name: "Test Trader", email: "trader@test.com")
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @other_system = System.discover_at(x: 1, y: 1, z: 1, user: @user)
    @ship = @user.ships.create!(
      name: "Trade Ship",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      current_system: @cradle
    )
  end

  # ===========================================
  # Basic Validations
  # ===========================================

  test "route requires name" do
    route = Route.new(user: @user, ship: @ship, stops: [])
    refute route.valid?
    assert route.errors[:name].present?
  end

  test "route requires user" do
    route = Route.new(name: "Test Route", ship: @ship, stops: [])
    refute route.valid?
    assert route.errors[:user].present?
  end

  test "route generates short_id on create" do
    route = @user.routes.create!(name: "My Route", ship: @ship, stops: [])
    assert route.short_id.present?
    assert route.short_id.start_with?("rt-")
  end

  # ===========================================
  # Stop Management
  # ===========================================

  test "route can have multiple stops" do
    route = @user.routes.create!(
      name: "Multi-stop",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @cradle.id, "action" => "unload", "commodity" => "water" }
      ]
    )

    assert_equal 2, route.stops.size
  end

  test "has_stops? returns true when stops exist" do
    route = @user.routes.create!(
      name: "With Stops",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }]
    )

    assert route.has_stops?
  end

  test "has_stops? returns false when no stops" do
    route = @user.routes.create!(name: "No Stops", ship: @ship, stops: [])
    refute route.has_stops?
  end

  # ===========================================
  # Profitability
  # ===========================================

  test "profitable? returns true when total_profit > 0" do
    route = @user.routes.create!(name: "Profitable", ship: @ship, stops: [], total_profit: 100)
    assert route.profitable?
  end

  test "profitable? returns false when total_profit is zero or negative" do
    route = @user.routes.create!(name: "Not Profitable", ship: @ship, stops: [], total_profit: 0)
    refute route.profitable?
  end

  # ===========================================
  # Cradle Location Check
  # ===========================================

  test "within_cradle? returns true when all stops are in The Cradle" do
    route = @user.routes.create!(
      name: "Cradle Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @cradle.id, "action" => "unload", "commodity" => "water" }
      ]
    )

    assert route.within_cradle?
  end

  test "within_cradle? returns false when stops include non-Cradle systems" do
    route = @user.routes.create!(
      name: "Mixed Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @other_system.id, "action" => "unload", "commodity" => "water" }
      ]
    )

    refute route.within_cradle?
  end

  test "within_cradle? returns false when no stops" do
    route = @user.routes.create!(name: "Empty", ship: @ship, stops: [])
    refute route.within_cradle?
  end

  # ===========================================
  # Tutorial Completion Criteria
  # ===========================================

  test "qualifies_for_tutorial? returns true when active, profitable, with stops in Cradle" do
    route = @user.routes.create!(
      name: "Tutorial Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @cradle.id, "action" => "sell", "commodity" => "food" }
      ],
      status: "active",
      total_profit: 50
    )

    assert route.qualifies_for_tutorial?
  end

  test "qualifies_for_tutorial? returns false when route is paused" do
    route = @user.routes.create!(
      name: "Paused Route",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "paused",
      total_profit: 50
    )

    refute route.qualifies_for_tutorial?
  end

  test "qualifies_for_tutorial? returns false when not profitable" do
    route = @user.routes.create!(
      name: "Unprofitable Route",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 0
    )

    refute route.qualifies_for_tutorial?
  end

  test "qualifies_for_tutorial? returns false when no stops" do
    route = @user.routes.create!(
      name: "Empty Route",
      ship: @ship,
      stops: [],
      status: "active",
      total_profit: 50
    )

    refute route.qualifies_for_tutorial?
  end
end
