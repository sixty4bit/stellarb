# frozen_string_literal: true

require "test_helper"

class TutorialCriteriaTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-zqj - Check if route matches tutorial criteria
  # Specific supply chain tutorial requirements
  # ===========================================

  setup do
    @user = User.create!(name: "Test Trader", email: "criteria_test@test.com")
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @other_system = System.discover_at(x: 5, y: 5, z: 5, user: @user)
    @ship = @user.ships.create!(
      name: "Trade Ship",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      current_system: @cradle
    )
  end

  # ===========================================
  # Route.meets_supply_chain_tutorial?
  # More specific criteria for the tutorial
  # ===========================================

  test "meets_supply_chain_tutorial? requires active status" do
    route = @user.routes.create!(
      name: "Paused Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @cradle.id, "action" => "sell", "commodity" => "food" }
      ],
      status: "paused",
      total_profit: 100
    )

    refute route.meets_supply_chain_tutorial?
  end

  test "meets_supply_chain_tutorial? requires profitable" do
    route = @user.routes.create!(
      name: "Unprofitable Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }
      ],
      status: "active",
      total_profit: 0
    )

    refute route.meets_supply_chain_tutorial?
  end

  test "meets_supply_chain_tutorial? requires at least one stop" do
    route = @user.routes.create!(
      name: "Empty Route",
      ship: @ship,
      stops: [],
      status: "active",
      total_profit: 100
    )

    refute route.meets_supply_chain_tutorial?
  end

  test "meets_supply_chain_tutorial? returns true for valid tutorial route" do
    route = @user.routes.create!(
      name: "Supply Chain",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @cradle.id, "action" => "unload", "commodity" => "food" }
      ],
      status: "active",
      total_profit: 50
    )

    assert route.meets_supply_chain_tutorial?
  end

  # ===========================================
  # Route.involves_commodity?
  # ===========================================

  test "involves_commodity? returns true when commodity is in any stop" do
    route = @user.routes.create!(
      name: "Water Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" },
        { "system_id" => @cradle.id, "action" => "sell", "commodity" => "water" }
      ],
      status: "active"
    )

    assert route.involves_commodity?("water")
  end

  test "involves_commodity? returns false when commodity not in any stop" do
    route = @user.routes.create!(
      name: "Food Route",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "food" }
      ],
      status: "active"
    )

    refute route.involves_commodity?("water")
  end

  test "involves_commodity? handles symbol keys in stops" do
    route = @user.routes.create!(
      name: "Mixed Keys",
      ship: @ship,
      stops: [
        { system_id: @cradle.id, action: "load", commodity: "ore" }
      ],
      status: "active"
    )

    assert route.involves_commodity?("ore")
  end

  # ===========================================
  # User.has_qualifying_supply_chain?
  # ===========================================

  test "user has_qualifying_supply_chain? returns false with no routes" do
    refute @user.has_qualifying_supply_chain?
  end

  test "user has_qualifying_supply_chain? returns false with non-qualifying routes" do
    @user.routes.create!(
      name: "Bad Route",
      ship: @ship,
      stops: [],
      status: "active",
      total_profit: 0
    )

    refute @user.has_qualifying_supply_chain?
  end

  test "user has_qualifying_supply_chain? returns true with qualifying route" do
    @user.routes.create!(
      name: "Good Supply Chain",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }
      ],
      status: "active",
      total_profit: 100
    )

    assert @user.has_qualifying_supply_chain?
  end

  # ===========================================
  # Integration: Only checks when user in cradle phase
  # ===========================================

  test "has_qualifying_supply_chain? considers tutorial phase" do
    # User starts in cradle phase
    assert @user.cradle?

    # Create qualifying route
    @user.routes.create!(
      name: "Tutorial Supply Chain",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 100
    )

    assert @user.has_qualifying_supply_chain?

    # User graduates - method still works (doesn't restrict by phase)
    @user.update!(tutorial_phase: :graduated)
    assert @user.has_qualifying_supply_chain?
  end
end
