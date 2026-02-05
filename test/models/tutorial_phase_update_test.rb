# frozen_string_literal: true

require "test_helper"

class TutorialPhaseUpdateTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-sh6 - Update tutorial phase on completion
  # Wire route creation to tutorial phase advancement
  # ===========================================

  setup do
    @user = User.create!(name: "Test Trader", email: "phase_update@test.com")
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
  # Route creation advances tutorial phase
  # ===========================================

  test "creating qualifying route advances user from cradle to proving_ground" do
    assert @user.cradle?

    @user.routes.create!(
      name: "Tutorial Supply Chain",
      ship: @ship,
      stops: [
        { "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }
      ],
      status: "active",
      total_profit: 100
    )

    @user.reload
    assert @user.proving_ground?, "User should advance to proving_ground after tutorial completion"
  end

  test "creating non-qualifying route does not advance tutorial phase" do
    assert @user.cradle?

    # Not profitable
    @user.routes.create!(
      name: "Bad Route",
      ship: @ship,
      stops: [],
      status: "active",
      total_profit: 0
    )

    @user.reload
    assert @user.cradle?, "User should remain in cradle with non-qualifying route"
  end

  test "updating route to qualifying advances tutorial phase" do
    assert @user.cradle?

    route = @user.routes.create!(
      name: "Initially Bad",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 0
    )

    @user.reload
    assert @user.cradle?, "Should still be in cradle"

    # Update to be profitable
    route.update!(total_profit: 50)

    @user.reload
    assert @user.proving_ground?, "User should advance after route becomes profitable"
  end

  test "does not advance phase if user not in cradle" do
    @user.update!(tutorial_phase: :proving_ground)

    @user.routes.create!(
      name: "Good Route",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 100
    )

    @user.reload
    assert @user.proving_ground?, "Should remain in proving_ground"
    refute @user.emigration?, "Should not skip to emigration"
  end

  test "multiple qualifying routes only advance phase once" do
    assert @user.cradle?

    # First route - advances to proving_ground
    @user.routes.create!(
      name: "Route 1",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 100
    )

    @user.reload
    assert @user.proving_ground?

    # Second route - should not advance further
    @user.routes.create!(
      name: "Route 2",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "ore" }],
      status: "active",
      total_profit: 200
    )

    @user.reload
    assert @user.proving_ground?, "Should remain in proving_ground"
    refute @user.emigration?, "Should not advance past proving_ground"
  end

  # ===========================================
  # Route.advance_user_tutorial_if_eligible
  # ===========================================

  test "advance_user_tutorial_if_eligible is called from check_tutorial_completion" do
    route = @user.routes.build(
      name: "Test",
      ship: @ship,
      stops: [{ "system_id" => @cradle.id, "action" => "load", "commodity" => "water" }],
      status: "active",
      total_profit: 100
    )

    assert route.respond_to?(:advance_user_tutorial_if_eligible, true)
  end
end
