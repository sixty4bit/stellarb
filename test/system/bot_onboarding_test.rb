require "application_system_test_case"

class BotOnboardingTest < ApplicationSystemTestCase
  # ==========================================
  # Onboarding Flow Integration Test
  #
  # Tests the complete onboarding flow:
  # 1. New user registration
  # 2. All onboarding steps completion
  # 3. Tutorial rewards verification
  # ==========================================

  # ==========================================
  # Test: Complete onboarding flow
  # ==========================================
  test "bot completes full onboarding flow" do
    # Step 1: Create a new user (simulating registration)
    user = User.create!(
      email: "newplayer_#{SecureRandom.hex(4)}@test.com",
      name: "New Player",
      short_id: "u-np#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    # Verify initial state
    assert user.needs_onboarding?, "New user should need onboarding"
    assert_equal "profile_setup", user.onboarding_step
    assert_nil user.onboarding_completed_at

    initial_credits = user.credits

    # Step 2: Progress through all onboarding steps
    expected_steps = User::ONBOARDING_STEPS

    expected_steps.each_with_index do |step, index|
      assert_equal step, user.onboarding_step,
        "Expected to be on step '#{step}', but was on '#{user.onboarding_step}'"

      # Advance to next step
      user.advance_onboarding_step!

      if index == expected_steps.length - 1
        # Last step should complete onboarding
        assert user.onboarding_complete?,
          "Onboarding should be complete after last step"
      elsif step == "navigation_tutorial"
        # Navigation tutorial gives a reward
        assert_equal initial_credits + 500, user.reload.credits,
          "Should receive 500 credits for completing navigation tutorial"
        initial_credits = user.credits
      end
    end

    # Step 3: Verify final state
    assert user.onboarding_complete?
    assert_not_nil user.onboarding_completed_at
  end

  # ==========================================
  # Test: User receives welcome messages
  # ==========================================
  test "new user receives welcome messages" do
    user = User.create!(
      email: "welcome_#{SecureRandom.hex(4)}@test.com",
      name: "Welcome Player",
      short_id: "u-wp#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    # User should have welcome messages
    assert user.messages.count > 0, "New user should have welcome messages"
  end

  # ==========================================
  # Test: Navigation tutorial awards credits
  # ==========================================
  test "completing navigation tutorial awards 500 credits" do
    user = User.create!(
      email: "navtest_#{SecureRandom.hex(4)}@test.com",
      name: "Nav Test Player",
      short_id: "u-nt#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 1000
    )

    # Advance to navigation_tutorial
    user.advance_onboarding_step!  # profile_setup -> ships_tour
    user.advance_onboarding_step!  # ships_tour -> navigation_tutorial

    assert_equal "navigation_tutorial", user.onboarding_step
    credits_before = user.credits

    # Complete navigation tutorial
    user.advance_onboarding_step!

    user.reload
    expected_credits = credits_before + 500
    assert_equal expected_credits, user.credits,
      "Should receive 500 credits for completing navigation tutorial"
  end

  # ==========================================
  # Test: Navigation tutorial creates achievement message
  # ==========================================
  test "completing navigation tutorial creates achievement message" do
    user = User.create!(
      email: "achievetest_#{SecureRandom.hex(4)}@test.com",
      name: "Achieve Test",
      short_id: "u-at#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    # Advance to and through navigation tutorial
    user.advance_onboarding_step!  # -> ships_tour
    user.advance_onboarding_step!  # -> navigation_tutorial
    user.advance_onboarding_step!  # complete nav tutorial

    # Should have an achievement message
    nav_message = user.messages.find_by(title: "Navigation Training Complete!")
    assert_not_nil nav_message, "Should have navigation completion message"
    assert_equal "achievement", nav_message.category
    assert_match /500 credits/, nav_message.body
  end

  # ==========================================
  # Test: User can skip onboarding
  # ==========================================
  test "user can skip onboarding" do
    user = User.create!(
      email: "skiptest_#{SecureRandom.hex(4)}@test.com",
      name: "Skip Test",
      short_id: "u-st#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    assert user.needs_onboarding?

    user.skip_onboarding!

    assert user.onboarding_complete?
    assert_not_nil user.onboarding_completed_at
  end

  # ==========================================
  # Test: User can reset onboarding
  # ==========================================
  test "user can reset onboarding after completion" do
    user = User.create!(
      email: "resettest_#{SecureRandom.hex(4)}@test.com",
      name: "Reset Test",
      short_id: "u-rt#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    # Complete onboarding
    user.skip_onboarding!
    assert user.onboarding_complete?

    # Reset
    user.reset_onboarding!

    assert_not user.onboarding_complete?
    assert_equal "profile_setup", user.onboarding_step
  end

  # ==========================================
  # Test: Each step can be queried
  # ==========================================
  test "enum helpers work for each onboarding step" do
    user = User.create!(
      email: "enumtest_#{SecureRandom.hex(4)}@test.com",
      name: "Enum Test",
      short_id: "u-et#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    assert user.profile_setup?

    user.advance_onboarding_step!
    assert user.ships_tour?

    user.advance_onboarding_step!
    assert user.navigation_tutorial?

    user.advance_onboarding_step!
    assert user.trade_routes?

    user.advance_onboarding_step!
    assert user.workers_overview?

    user.advance_onboarding_step!
    assert user.inbox_introduction?
  end

  # ==========================================
  # Test: current_onboarding_step returns nil when complete
  # ==========================================
  test "current_onboarding_step returns nil when complete" do
    user = User.create!(
      email: "niltest_#{SecureRandom.hex(4)}@test.com",
      name: "Nil Test",
      short_id: "u-xt#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    user.skip_onboarding!

    assert_nil user.current_onboarding_step
  end

  # ==========================================
  # Test: on_onboarding_step? works correctly
  # ==========================================
  test "on_onboarding_step? returns correct boolean" do
    user = User.create!(
      email: "steptest_#{SecureRandom.hex(4)}@test.com",
      name: "Step Test",
      short_id: "u-s2#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    assert user.on_onboarding_step?(:profile_setup)
    assert user.on_onboarding_step?("profile_setup")
    assert_not user.on_onboarding_step?(:ships_tour)
  end

  # ==========================================
  # Test: Scopes for onboarding status
  # ==========================================
  test "onboarding scopes work correctly" do
    onboarding_user = User.create!(
      email: "onb1_#{SecureRandom.hex(4)}@test.com",
      name: "Onboarding User",
      short_id: "u-o1#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    complete_user = User.create!(
      email: "onb2_#{SecureRandom.hex(4)}@test.com",
      name: "Complete User",
      short_id: "u-o2#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )
    complete_user.skip_onboarding!

    assert_includes User.onboarding, onboarding_user
    assert_not_includes User.onboarding, complete_user

    assert_includes User.onboarding_complete, complete_user
    assert_not_includes User.onboarding_complete, onboarding_user
  end

  # ==========================================
  # Test: Full game loop after onboarding
  # ==========================================
  test "user can perform game actions after completing onboarding" do
    user = User.create!(
      email: "fullgame_#{SecureRandom.hex(4)}@test.com",
      name: "Full Game Player",
      short_id: "u-fg#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 5000
    )

    # Complete onboarding
    User::ONBOARDING_STEPS.length.times { user.advance_onboarding_step! }
    assert user.onboarding_complete?

    # Create a system for the user
    system = System.create!(
      x: 100, y: 100, z: 100,
      name: "Test System",
      short_id: "sy-ts#{SecureRandom.hex(2)}",
      properties: {
        "star_type" => "yellow_dwarf",
        "planet_count" => 3,
        "hazard_level" => 10,
        "base_prices" => { "ore" => 100 }
      }
    )

    # Now user should be able to perform game actions
    # Create a ship
    ship = Ship.create!(
      name: "Post-Tutorial Ship",
      short_id: "sh-pt#{SecureRandom.hex(2)}",
      user: user,
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: system,
      cargo: {},
      ship_attributes: { "cargo_capacity" => 50 }
    )

    assert_includes user.ships.reload, ship
    assert ship.operational?
  end

  # ==========================================
  # Test: Advancing past completion does nothing
  # ==========================================
  test "advancing onboarding after completion does nothing" do
    user = User.create!(
      email: "noop_#{SecureRandom.hex(4)}@test.com",
      name: "Noop Test",
      short_id: "u-no#{SecureRandom.hex(2)}",
      level_tier: 1,
      credits: 500
    )

    user.skip_onboarding!
    completed_at = user.onboarding_completed_at
    step = user.onboarding_step

    # Try to advance
    user.advance_onboarding_step!

    # Nothing should change
    assert_equal completed_at, user.onboarding_completed_at
    assert_equal step, user.onboarding_step
  end
end
