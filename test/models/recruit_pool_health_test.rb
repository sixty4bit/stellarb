# frozen_string_literal: true

require "test_helper"

class RecruitPoolHealthTest < ActiveSupport::TestCase
  fixtures []

  setup do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE hirings, hired_recruits, routes, recruits, ships, buildings, users RESTART IDENTITY CASCADE")
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
  end

  # =====================
  # Pool Health Check
  # =====================

  test "pool_needs_refresh? returns true when no recruits exist" do
    assert Recruit.pool_needs_refresh?, "Should need refresh when pool is empty"
  end

  test "pool_needs_refresh? returns true when all recruits are expired" do
    Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expired One",
      available_at: 2.hours.ago, expires_at: 1.hour.ago
    )

    assert Recruit.pool_needs_refresh?, "Should need refresh when all recruits expired"
  end

  test "pool_needs_refresh? returns false when valid recruits exist" do
    Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Fresh One",
      available_at: 5.minutes.ago, expires_at: 1.hour.from_now
    )

    assert_not Recruit.pool_needs_refresh?, "Should not need refresh when valid recruits exist"
  end

  test "pool_needs_refresh? returns true when oldest recruit is near expiration" do
    # Create recruit that expires in 5 minutes (within 10 minute threshold)
    Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expiring Soon",
      available_at: 25.minutes.ago, expires_at: 5.minutes.from_now
    )

    assert Recruit.pool_needs_refresh?, "Should need refresh when oldest recruit expires within threshold"
  end

  test "pool_needs_refresh? uses configurable threshold" do
    # Create recruit expiring in 15 minutes
    Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expiring Later",
      available_at: 20.minutes.ago, expires_at: 15.minutes.from_now
    )

    # With default 10 min threshold, should not need refresh
    assert_not Recruit.pool_needs_refresh?, "15min remaining > 10min threshold"

    # With 20 min threshold, should need refresh
    assert Recruit.pool_needs_refresh?(threshold: 20.minutes), "15min remaining < 20min threshold"
  end

  # =====================
  # First Recruit Age Check
  # =====================

  test "oldest_expiring_recruit returns nil when pool is empty" do
    assert_nil Recruit.oldest_expiring_recruit
  end

  test "oldest_expiring_recruit returns recruit expiring soonest" do
    later = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Later",
      available_at: 5.minutes.ago, expires_at: 2.hours.from_now
    )

    sooner = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "navigator",
      skill: 60, chaos_factor: 30, name: "Sooner",
      available_at: 10.minutes.ago, expires_at: 30.minutes.from_now
    )

    assert_equal sooner, Recruit.oldest_expiring_recruit
  end

  test "oldest_expiring_recruit ignores already expired recruits" do
    expired = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expired",
      available_at: 2.hours.ago, expires_at: 1.hour.ago
    )

    active = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "navigator",
      skill: 60, chaos_factor: 30, name: "Active",
      available_at: 5.minutes.ago, expires_at: 1.hour.from_now
    )

    assert_equal active, Recruit.oldest_expiring_recruit
  end
end
