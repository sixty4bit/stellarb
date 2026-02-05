# frozen_string_literal: true

require "test_helper"

class RecruiterRefreshJobTest < ActiveJob::TestCase
  # Don't load fixtures for this test
  fixtures []

  setup do
    # Truncate tables properly (disable/enable foreign keys)
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE hirings, hired_recruits, routes, recruits, ships, buildings, users RESTART IDENTITY CASCADE")

    # Create some active users at different tiers
    @tier1_user1 = User.create!(email: "t1u1@example.com", name: "Tier1 User1", level_tier: 1)
    @tier1_user2 = User.create!(email: "t1u2@example.com", name: "Tier1 User2", level_tier: 1)
    @tier2_user = User.create!(email: "t2u1@example.com", name: "Tier2 User1", level_tier: 2)
  end

  # =====================
  # Pool Generation Tests
  # =====================

  test "generates recruits for each level tier with active players" do
    RecruiterRefreshJob.perform_now

    tier1_recruits = Recruit.available_for(@tier1_user1)
    tier2_recruits = Recruit.available_for(@tier2_user)

    assert tier1_recruits.any?, "Should generate recruits for tier 1"
    assert tier2_recruits.any?, "Should generate recruits for tier 2"
  end

  test "generates recruits for all NPC classes" do
    RecruiterRefreshJob.perform_now

    tier1_recruits = Recruit.available_for(@tier1_user1)
    classes = tier1_recruits.pluck(:npc_class).uniq.sort

    assert_includes classes, "governor"
    assert_includes classes, "navigator"
    assert_includes classes, "engineer"
    assert_includes classes, "marine"
  end

  test "generates minimum 10 recruits per class when few players" do
    RecruiterRefreshJob.perform_now

    tier1_recruits = Recruit.available_for(@tier1_user1)
    class_counts = tier1_recruits.group(:npc_class).count

    Recruit::NPC_CLASSES.each do |npc_class|
      assert class_counts[npc_class] >= 10, "Should have at least 10 #{npc_class}s, got #{class_counts[npc_class]}"
    end
  end

  test "pool size scales with active players (0.3 per class)" do
    # Create 100 active tier 1 users
    100.times do |i|
      User.create!(email: "bulk#{i}@example.com", name: "Bulk User #{i}", level_tier: 1)
    end

    RecruiterRefreshJob.perform_now

    tier1_recruits = Recruit.available_for(@tier1_user1)
    class_counts = tier1_recruits.group(:npc_class).count

    # With 102 users (2 from setup + 100 bulk), we expect ~30 per class (102 * 0.3)
    Recruit::NPC_CLASSES.each do |npc_class|
      assert class_counts[npc_class] >= 30, "Should have at least 30 #{npc_class}s with 102 users, got #{class_counts[npc_class]}"
      assert class_counts[npc_class] <= 35, "Should have at most ~35 #{npc_class}s with 102 users, got #{class_counts[npc_class]}"
    end
  end

  # =====================
  # Expiration Tests
  # =====================

  test "cleans up expired recruits" do
    # Create an expired recruit
    expired = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Expired One",
      available_at: 2.hours.ago, expires_at: 1.hour.ago
    )

    RecruiterRefreshJob.perform_now

    assert_not Recruit.exists?(expired.id), "Should delete expired recruits"
  end

  test "does not delete active recruits" do
    active = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20, name: "Active One",
      available_at: 1.hour.ago, expires_at: 1.hour.from_now
    )

    RecruiterRefreshJob.perform_now

    assert Recruit.exists?(active.id), "Should keep active recruits"
  end

  # =====================
  # Rotation Timing Tests
  # =====================

  test "new recruits have 30-90 minute expiration window" do
    RecruiterRefreshJob.perform_now

    now = Time.current
    Recruit.available_for(@tier1_user1).each do |recruit|
      window_length = recruit.expires_at - recruit.available_at
      minutes = window_length / 60.0

      assert minutes >= 29, "Recruit should have at least 29 min window, got #{minutes}"
      assert minutes <= 91, "Recruit should have at most 91 min window, got #{minutes}"
    end
  end

  # =====================
  # Scheduling Tests
  # =====================

  test "reschedules itself for next rotation" do
    assert_enqueued_with(job: RecruiterRefreshJob) do
      RecruiterRefreshJob.perform_now
    end
  end

  test "reschedules with random delay between 30-90 minutes" do
    # Perform the job multiple times and check the delays
    delays = []
    10.times do
      RecruiterRefreshJob.perform_now
      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.last
      delay_seconds = enqueued[:at] - Time.current.to_f
      delay_minutes = delay_seconds / 60.0
      delays << delay_minutes
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    end

    # All delays should be in the 30-90 minute range
    delays.each do |delay|
      assert delay >= 29, "Delay should be at least 29 minutes, got #{delay}"
      assert delay <= 91, "Delay should be at most 91 minutes, got #{delay}"
    end

    # With 10 samples, we should see some variation (not all the same)
    assert delays.uniq.length > 1, "Delays should have some randomness"
  end

  # =====================
  # Shared Pool Tests
  # =====================

  test "same tier players see identical recruit pool" do
    RecruiterRefreshJob.perform_now

    user1_recruits = Recruit.available_for(@tier1_user1).order(:id).pluck(:id)
    user2_recruits = Recruit.available_for(@tier1_user2).order(:id).pluck(:id)

    assert_equal user1_recruits, user2_recruits, "Same tier users should see same recruits"
  end

  test "different tier players see different recruit pools" do
    RecruiterRefreshJob.perform_now

    tier1_recruits = Recruit.available_for(@tier1_user1).pluck(:id)
    tier2_recruits = Recruit.available_for(@tier2_user).pluck(:id)

    # They should have no overlap
    overlap = tier1_recruits & tier2_recruits
    assert_empty overlap, "Different tier users should see different pools"
  end

  # =====================
  # Idempotency Tests
  # =====================

  test "running job twice doesn't duplicate recruits unnecessarily" do
    RecruiterRefreshJob.perform_now
    first_count = Recruit.available_for(@tier1_user1).count

    RecruiterRefreshJob.perform_now
    second_count = Recruit.available_for(@tier1_user1).count

    # The counts should be similar (some might expire and be regenerated)
    assert_in_delta first_count, second_count, 10, "Second run shouldn't dramatically change count"
  end
end
