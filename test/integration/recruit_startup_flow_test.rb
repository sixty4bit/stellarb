# frozen_string_literal: true

require "test_helper"

class RecruitStartupFlowTest < ActiveJob::TestCase
  fixtures []

  setup do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE hirings, hired_recruits, routes, recruits, ships, buildings, users RESTART IDENTITY CASCADE")
    clear_enqueued_jobs
  end

  # =====================
  # Full Startup Flow Integration Tests
  # =====================

  test "startup flow: empty pool generates recruits and schedules job" do
    # Simulate server startup with no recruits
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    assert_equal 0, Recruit.count, "Precondition: no recruits"

    RecruiterRefreshJob.ensure_pool_ready

    # Should have generated recruits
    assert Recruit.count > 0, "Should generate recruits for tier 1"

    # Should have scheduled a job
    jobs = enqueued_jobs.select { |j| j["job_class"] == "RecruiterRefreshJob" }
    assert_equal 1, jobs.count, "Should schedule exactly one job"
  end

  test "startup flow: stale pool refreshes and schedules job" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    # Create stale recruits (expiring in 5 minutes)
    10.times do
      Recruit.create!(
        level_tier: 1, race: "vex", npc_class: "engineer",
        skill: 50, chaos_factor: 20, name: "Stale",
        available_at: 30.minutes.ago, expires_at: 5.minutes.from_now
      )
    end

    initial_count = Recruit.count
    RecruiterRefreshJob.ensure_pool_ready

    # Should have generated fresh recruits (more than we started with)
    assert Recruit.count > initial_count, "Should generate fresh recruits"

    # New recruits should have longer expiration
    newest = Recruit.order(created_at: :desc).first
    assert newest.expires_at > 20.minutes.from_now, "New recruits should have longer expiration"
  end

  test "startup flow: healthy pool skips generation but schedules job" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    # Create healthy pool
    10.times do
      Recruit.create!(
        level_tier: 1, race: "vex", npc_class: "engineer",
        skill: 50, chaos_factor: 20, name: "Healthy",
        available_at: 5.minutes.ago, expires_at: 1.hour.from_now
      )
    end

    initial_count = Recruit.count
    RecruiterRefreshJob.ensure_pool_ready

    # Should NOT have generated more recruits
    assert_equal initial_count, Recruit.count, "Should not generate when pool is healthy"

    # But should still schedule a job for rotation
    jobs = enqueued_jobs.select { |j| j["job_class"] == "RecruiterRefreshJob" }
    assert_equal 1, jobs.count, "Should schedule job to maintain rotation"
  end

  test "startup flow: multiple boots are idempotent" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    # Simulate first boot
    RecruiterRefreshJob.ensure_pool_ready
    first_count = Recruit.count
    first_job_count = enqueued_jobs.count

    # Simulate second boot (shouldn't duplicate)
    RecruiterRefreshJob.ensure_pool_ready
    second_count = Recruit.count
    second_job_count = enqueued_jobs.count

    # Counts should be similar
    assert_in_delta first_count, second_count, 5, "Pool size should be stable across boots"
    assert_equal first_job_count, second_job_count, "Should not schedule duplicate jobs"
  end

  test "startup flow: expired recruits are cleaned up" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    # Create expired recruits
    3.times do
      Recruit.create!(
        level_tier: 1, race: "vex", npc_class: "engineer",
        skill: 50, chaos_factor: 20, name: "Expired",
        available_at: 2.hours.ago, expires_at: 1.hour.ago
      )
    end

    expired_ids = Recruit.expired.pluck(:id)
    assert_equal 3, expired_ids.count, "Precondition: 3 expired recruits"

    RecruiterRefreshJob.ensure_pool_ready

    # Expired should be gone
    expired_ids.each do |id|
      assert_not Recruit.exists?(id), "Expired recruit #{id} should be deleted"
    end
  end

  test "startup flow: multi-tier pool generation" do
    # Create users at different tiers
    User.create!(email: "t1@example.com", name: "Tier1", level_tier: 1)
    User.create!(email: "t2@example.com", name: "Tier2", level_tier: 2)
    User.create!(email: "t3@example.com", name: "Tier3", level_tier: 3)

    RecruiterRefreshJob.ensure_pool_ready

    # Should have recruits for all tiers
    tier1_count = Recruit.where(level_tier: 1).count
    tier2_count = Recruit.where(level_tier: 2).count
    tier3_count = Recruit.where(level_tier: 3).count

    assert tier1_count > 0, "Should have tier 1 recruits"
    assert tier2_count > 0, "Should have tier 2 recruits"
    assert tier3_count > 0, "Should have tier 3 recruits"
  end

  test "startup flow: all NPC classes are represented" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    RecruiterRefreshJob.ensure_pool_ready

    classes = Recruit.where(level_tier: 1).pluck(:npc_class).uniq.sort

    Recruit::NPC_CLASSES.sort.each do |expected_class|
      assert_includes classes, expected_class, "Should generate #{expected_class} class"
    end
  end

  # =====================
  # Pool Health Check Integration
  # =====================

  test "pool_needs_refresh? integrates correctly with ensure_pool_ready" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    # Empty pool should need refresh
    assert Recruit.pool_needs_refresh?

    RecruiterRefreshJob.ensure_pool_ready

    # After refresh, pool should be healthy
    assert_not Recruit.pool_needs_refresh?
  end

  # =====================
  # Job Scheduling Integration
  # =====================

  test "scheduled job will execute and reschedule" do
    @user = User.create!(email: "test@example.com", name: "Test", level_tier: 1)

    # Startup schedules job
    RecruiterRefreshJob.ensure_pool_ready
    clear_enqueued_jobs

    # Execute the scheduled job
    RecruiterRefreshJob.perform_now

    # Should reschedule for next rotation
    jobs = enqueued_jobs.select { |j| j["job_class"] == "RecruiterRefreshJob" }
    assert_equal 1, jobs.count, "Job should reschedule itself"
  end
end
