# frozen_string_literal: true

require "test_helper"

class RecruiterTierFilteringTest < ActiveJob::TestCase
  # Task stellarb-636.1: Integration tests for recruiter tier filtering
  #
  # Verifies that the recruiter system properly filters recruits by player level tier.
  # Model scope tests verify the core filtering logic works correctly.

  # Don't load fixtures - we'll create what we need
  fixtures []

  setup do
    # Clean slate
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE hirings, hired_recruits, routes, recruits, ships, buildings, systems, users RESTART IDENTITY CASCADE"
    )
  end

  # ================================================
  # Model Scope Tests - Core Filtering Logic
  # ================================================

  test "available_for scope returns only recruits matching user tier" do
    user = User.create!(
      email: "tier1@test.com",
      name: "Tier1 Player",
      level_tier: 1,
      credits: 10_000,
      profile_completed_at: Time.current
    )

    tier1_recruit = create_recruit(level_tier: 1, name: "T1")
    tier2_recruit = create_recruit(level_tier: 2, name: "T2")
    tier3_recruit = create_recruit(level_tier: 3, name: "T3")

    available = Recruit.available_for(user)

    assert_includes available, tier1_recruit, "Tier 1 user should see tier 1 recruits"
    refute_includes available, tier2_recruit, "Tier 1 user should NOT see tier 2 recruits"
    refute_includes available, tier3_recruit, "Tier 1 user should NOT see tier 3 recruits"
  end

  test "available_for_tier scope filters by tier number" do
    tier1_recruit = create_recruit(level_tier: 1, name: "T1")
    tier2_recruit = create_recruit(level_tier: 2, name: "T2")
    tier3_recruit = create_recruit(level_tier: 3, name: "T3")

    tier1_pool = Recruit.available_for_tier(1)
    tier2_pool = Recruit.available_for_tier(2)
    tier3_pool = Recruit.available_for_tier(3)

    assert_includes tier1_pool, tier1_recruit
    refute_includes tier1_pool, tier2_recruit
    refute_includes tier1_pool, tier3_recruit

    assert_includes tier2_pool, tier2_recruit
    refute_includes tier2_pool, tier1_recruit
    refute_includes tier2_pool, tier3_recruit

    assert_includes tier3_pool, tier3_recruit
    refute_includes tier3_pool, tier1_recruit
    refute_includes tier3_pool, tier2_recruit
  end

  test "available_for excludes expired recruits" do
    user = User.create!(
      email: "test@test.com",
      name: "Test Player",
      level_tier: 1,
      credits: 10_000,
      profile_completed_at: Time.current
    )

    active_recruit = create_recruit(level_tier: 1, name: "Active")
    expired_recruit = create_recruit(
      level_tier: 1,
      name: "Expired",
      available_at: 3.hours.ago,
      expires_at: 1.hour.ago
    )

    available = Recruit.available_for(user)

    assert_includes available, active_recruit
    refute_includes available, expired_recruit, "Expired recruits should not be available"
  end

  test "available_for excludes future recruits" do
    user = User.create!(
      email: "test@test.com",
      name: "Test Player",
      level_tier: 1,
      credits: 10_000,
      profile_completed_at: Time.current
    )

    available_recruit = create_recruit(level_tier: 1, name: "Available")
    future_recruit = create_recruit(
      level_tier: 1,
      name: "Future",
      available_at: 1.hour.from_now,
      expires_at: 3.hours.from_now
    )

    available = Recruit.available_for(user)

    assert_includes available, available_recruit
    refute_includes available, future_recruit, "Future recruits should not be available yet"
  end

  test "tier pools are independent - different users see different recruits" do
    tier1_user = User.create!(
      email: "tier1@test.com",
      name: "Tier1 Player",
      level_tier: 1,
      credits: 10_000,
      profile_completed_at: Time.current
    )
    tier2_user = User.create!(
      email: "tier2@test.com",
      name: "Tier2 Player",
      level_tier: 2,
      credits: 10_000,
      profile_completed_at: Time.current
    )

    tier1_recruit = create_recruit(level_tier: 1, name: "OnlyForTier1")
    tier2_recruit = create_recruit(level_tier: 2, name: "OnlyForTier2")

    tier1_available = Recruit.available_for(tier1_user)
    tier2_available = Recruit.available_for(tier2_user)

    # Tier 1 user only sees tier 1
    assert_includes tier1_available, tier1_recruit
    refute_includes tier1_available, tier2_recruit

    # Tier 2 user only sees tier 2
    assert_includes tier2_available, tier2_recruit
    refute_includes tier2_available, tier1_recruit
  end

  test "available_for? instance method respects tier matching" do
    tier1_user = User.create!(
      email: "tier1@test.com",
      name: "Tier1 Player",
      level_tier: 1,
      credits: 10_000,
      profile_completed_at: Time.current
    )

    tier1_recruit = create_recruit(level_tier: 1, name: "T1")
    tier2_recruit = create_recruit(level_tier: 2, name: "T2")

    assert tier1_recruit.available_for?(tier1_user), "Tier 1 recruit should be available for tier 1 user"
    refute tier2_recruit.available_for?(tier1_user), "Tier 2 recruit should NOT be available for tier 1 user"
  end

  private

  def create_recruit(level_tier:, name:, available_at: 1.hour.ago, expires_at: 2.hours.from_now)
    Recruit.create!(
      level_tier: level_tier,
      name: name,
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: available_at,
      expires_at: expires_at,
      base_stats: {},
      employment_history: []
    )
  end
end
