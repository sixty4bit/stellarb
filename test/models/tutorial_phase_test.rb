# frozen_string_literal: true

require "test_helper"

class TutorialPhaseTest < ActiveSupport::TestCase
  # ===========================================
  # Task: stellarb-zao - Tutorial state machine
  # Track user tutorial_phase progression
  # ===========================================

  # ===========================================
  # Phase Enum
  # ===========================================

  test "new users start in cradle phase" do
    user = User.create!(name: "New Player", email: "newplayer@test.com")
    assert_equal "cradle", user.tutorial_phase
  end

  test "tutorial_phase has valid enum values" do
    user = User.create!(name: "Test", email: "enum@test.com")

    # Valid phases from ROADMAP:
    # Phase 1: cradle (learn basics)
    # Phase 2: proving_ground (exploration)
    # Phase 3: emigration (the drop)
    # graduated (real game)

    assert user.cradle?
    user.update!(tutorial_phase: :proving_ground)
    assert user.proving_ground?
    user.update!(tutorial_phase: :emigration)
    assert user.emigration?
    user.update!(tutorial_phase: :graduated)
    assert user.graduated?
  end

  # ===========================================
  # Phase Progression
  # ===========================================

  test "can progress from cradle to proving_ground" do
    user = User.create!(name: "Test", email: "progress1@test.com")
    assert user.cradle?

    user.advance_tutorial_phase!
    assert user.proving_ground?
  end

  test "can progress from proving_ground to emigration" do
    user = User.create!(name: "Test", email: "progress2@test.com", tutorial_phase: :proving_ground)
    
    user.advance_tutorial_phase!
    assert user.emigration?
  end

  test "can progress from emigration to graduated" do
    user = User.create!(name: "Test", email: "progress3@test.com", tutorial_phase: :emigration)
    
    user.advance_tutorial_phase!
    assert user.graduated?
  end

  test "cannot advance past graduated" do
    user = User.create!(name: "Test", email: "progress4@test.com", tutorial_phase: :graduated)
    
    # Should not raise, but should stay at graduated
    user.advance_tutorial_phase!
    assert user.graduated?
  end

  # ===========================================
  # Phase Checks
  # ===========================================

  test "in_tutorial? returns true for tutorial phases" do
    user = User.create!(name: "Test", email: "intut@test.com")

    assert user.in_tutorial?

    user.update!(tutorial_phase: :proving_ground)
    assert user.in_tutorial?

    user.update!(tutorial_phase: :emigration)
    assert user.in_tutorial?
  end

  test "in_tutorial? returns false for graduated users" do
    user = User.create!(name: "Test", email: "notintut@test.com", tutorial_phase: :graduated)
    
    refute user.in_tutorial?
  end

  test "can_graduate? returns true only when in emigration phase" do
    user = User.create!(name: "Test", email: "cangrad@test.com")

    refute user.can_graduate?

    user.update!(tutorial_phase: :proving_ground)
    refute user.can_graduate?

    user.update!(tutorial_phase: :emigration)
    assert user.can_graduate?

    user.update!(tutorial_phase: :graduated)
    refute user.can_graduate?
  end

  # ===========================================
  # Phase Requirements
  # ===========================================

  test "cradle_complete? checks for first automated route" do
    user = User.create!(name: "Test", email: "cradlecomp@test.com")
    cradle = System.discover_at(x: 0, y: 0, z: 0, user: user)
    ship = user.ships.create!(name: "Starter Ship", race: "vex", hull_size: "transport", variant_idx: 0, current_system: cradle)

    # No route yet
    refute user.cradle_complete?

    # Create a profitable automated route (Water -> Hydroponics)
    route = user.routes.create!(
      name: "Tutorial Route",
      ship: ship,
      stops: [
        { system_id: cradle.id, action: "load", commodity: "water" },
        { system_id: cradle.id, action: "sell", commodity: "water" }
      ],
      status: "active",
      total_profit: 100
    )

    assert user.cradle_complete?
  end

  test "can_leave_cradle? returns true when cradle phase is complete" do
    user = User.create!(name: "Test", email: "canleave@test.com")
    cradle = System.discover_at(x: 0, y: 0, z: 0, user: user)
    ship = user.ships.create!(name: "Starter Ship", race: "vex", hull_size: "transport", variant_idx: 0, current_system: cradle)

    # Not complete yet
    refute user.can_leave_cradle?

    # Complete the tutorial objective
    user.routes.create!(
      name: "Tutorial Route",
      ship: ship,
      stops: [{ system_id: cradle.id, action: "load", commodity: "water" }],
      status: "active",
      total_profit: 100
    )

    assert user.can_leave_cradle?
  end
end
