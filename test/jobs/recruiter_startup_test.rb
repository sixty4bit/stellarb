# frozen_string_literal: true

require "test_helper"

class RecruiterStartupTest < ActiveJob::TestCase
  fixtures []

  setup do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE hirings, hired_recruits, routes, recruits, ships, buildings, users RESTART IDENTITY CASCADE")
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
  end

  # =====================
  # Idempotent Startup Method
  # =====================

  test "ensure_pool_ready generates recruits when pool is empty" do
    initial_count = Recruit.count
    RecruiterRefreshJob.ensure_pool_ready
    assert Recruit.count > initial_count, "Should generate recruits when pool is empty"
  end

  test "ensure_pool_ready schedules next job when pool is empty" do
    assert_enqueued_with(job: RecruiterRefreshJob) do
      RecruiterRefreshJob.ensure_pool_ready
    end
  end

  test "ensure_pool_ready does not generate recruits when pool is healthy" do
    # Create a healthy pool (recruits expiring in 1 hour)
    10.times do
      Recruit.create!(
        level_tier: 1, race: "vex", npc_class: "engineer",
        skill: 50, chaos_factor: 20, name: "Healthy",
        available_at: 5.minutes.ago, expires_at: 1.hour.from_now
      )
    end

    initial_count = Recruit.count
    RecruiterRefreshJob.ensure_pool_ready

    assert_equal initial_count, Recruit.count, "Should not create recruits when pool is healthy"
  end

  test "ensure_pool_ready does schedule job even when pool is healthy (to ensure rotation continues)" do
    # Create a healthy pool
    Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Healthy",
      available_at: 5.minutes.ago, expires_at: 1.hour.from_now
    )

    # Should still schedule a job to maintain rotation
    assert_enqueued_with(job: RecruiterRefreshJob) do
      RecruiterRefreshJob.ensure_pool_ready
    end
  end

  test "ensure_pool_ready refreshes pool when recruits are near expiration" do
    # Create pool with recruits expiring soon (5 minutes)
    old_recruit = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expiring",
      available_at: 30.minutes.ago, expires_at: 5.minutes.from_now
    )

    initial_count = Recruit.count
    RecruiterRefreshJob.ensure_pool_ready

    assert Recruit.count > initial_count, "Should create new recruits when pool is stale"
  end

  test "ensure_pool_ready is idempotent - multiple calls produce same result" do
    # First call - creates recruits
    RecruiterRefreshJob.ensure_pool_ready
    first_count = Recruit.count

    # Clear job queue to test scheduling
    clear_enqueued_jobs

    # Second immediate call - should not double up
    RecruiterRefreshJob.ensure_pool_ready
    second_count = Recruit.count

    # Counts should be similar (within tolerance for any expired/regenerated)
    assert_in_delta first_count, second_count, 5, "Multiple calls should not dramatically change count"
  end

  test "ensure_pool_ready cleans expired recruits" do
    # Create expired recruit
    expired = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expired",
      available_at: 2.hours.ago, expires_at: 1.hour.ago
    )

    RecruiterRefreshJob.ensure_pool_ready

    assert_not Recruit.exists?(expired.id), "Should clean up expired recruits"
  end
end
