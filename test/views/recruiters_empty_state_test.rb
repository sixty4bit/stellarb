# frozen_string_literal: true

require "test_helper"

class RecruitersEmptyStateTest < ActionDispatch::IntegrationTest
  # Task stellarb-636.2: Empty state for new players with no recruits
  #
  # Verifies the recruiter view shows a helpful empty state when no
  # recruits are available, explaining the system to new players.

  setup do
    @user = users(:pilot)
    sign_in_as(@user)
    # Clear recruits to trigger empty state (handle FK constraints in correct order)
    Hiring.delete_all
    HiredRecruit.delete_all
    Recruit.delete_all
  end

  test "empty state shows informative message when no recruits available" do
    get recruiters_path
    assert_response :success

    # Should explain what the recruiter system is
    assert_match(/Workers help your fleet operate/i, response.body,
      "Empty state should explain what workers do")
  end

  test "empty state encourages player to check back" do
    get recruiters_path
    assert_response :success

    # Should encourage checking back
    assert_match(/Check back soon/i, response.body,
      "Empty state should encourage checking back")
  end

  test "empty state explains pool refresh system" do
    get recruiters_path
    assert_response :success

    # Should explain the refresh system
    assert_match(/refresh/i, response.body,
      "Empty state should mention pool refresh")
  end

  test "empty state shows when recruits exist for different tier" do
    # Create recruit for different tier
    Recruit.create!(
      level_tier: @user.level_tier + 1,
      name: "OtherTierRecruit",
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: 1.hour.ago,
      expires_at: 2.hours.from_now,
      base_stats: {},
      employment_history: []
    )

    get recruiters_path
    assert_response :success

    # Should still show empty state (recruits exist but not for this tier)
    assert_match(/Workers help your fleet operate/i, response.body,
      "Should show empty state when no recruits for user's tier")
    refute_match(/OtherTierRecruit/, response.body,
      "Should not show recruits from other tiers")
  end
end
