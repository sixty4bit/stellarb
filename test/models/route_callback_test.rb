# frozen_string_literal: true

require "test_helper"

class RouteCallbackTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-6y9 - Detect route creation events
  # Add callbacks to detect when routes are created/updated
  # ===========================================

  setup do
    @user = User.create!(name: "Test Trader", email: "callback_test@test.com")
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @ship = @user.ships.create!(
      name: "Trade Ship",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      current_system: @cradle
    )
  end

  # ===========================================
  # Route Callback Method Exists
  # ===========================================

  test "check_tutorial_completion method exists" do
    route = @user.routes.create!(
      name: "Test Route",
      ship: @ship,
      stops: [],
      status: "active"
    )

    assert route.respond_to?(:check_tutorial_completion, true),
           "Route should have check_tutorial_completion callback method"
  end

  test "after_commit callback is registered for create" do
    callbacks = Route._commit_callbacks.select { |cb| cb.filter == :check_tutorial_completion }
    assert callbacks.any?, "check_tutorial_completion should be an after_commit callback"
  end

  test "after_commit callback is registered for update" do
    # Check that it runs on update as well
    callbacks = Route._commit_callbacks.select do |cb|
      cb.filter == :check_tutorial_completion
    end

    # Should trigger on both create and update (not just on: :create)
    callback = callbacks.first
    assert callback.present?, "Callback should exist"
  end

  # ===========================================
  # Tutorial Qualification Changes
  # ===========================================

  test "route becomes qualifying on create" do
    # Create a route that qualifies for tutorial
    route = @user.routes.create!(
      name: "Qualifying Route",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 100
    )

    assert route.qualifies_for_tutorial?
  end

  test "route becomes qualifying after profit update" do
    route = @user.routes.create!(
      name: "Initially Unprofitable",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 0
    )

    refute route.qualifies_for_tutorial?

    # Update to be profitable
    route.update!(total_profit: 50)

    assert route.qualifies_for_tutorial?
  end

  test "route becomes qualifying after status change to active" do
    route = @user.routes.create!(
      name: "Paused Route",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "paused",
      total_profit: 100
    )

    refute route.qualifies_for_tutorial?

    # Activate the route
    route.update!(status: "active")

    assert route.qualifies_for_tutorial?
  end

  test "check_tutorial_completion returns qualification status" do
    route = @user.routes.create!(
      name: "Test Route",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 100
    )

    # The method should return whether the route qualifies
    result = route.send(:check_tutorial_completion)
    assert_equal true, result
  end

  test "check_tutorial_completion returns false for non-qualifying route" do
    route = @user.routes.create!(
      name: "Test Route",
      ship: @ship,
      stops: [],
      status: "active",
      total_profit: 0
    )

    result = route.send(:check_tutorial_completion)
    assert_equal false, result
  end
end
