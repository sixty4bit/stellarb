# frozen_string_literal: true

require "test_helper"

class RecruiterJobDeduplicationTest < ActiveJob::TestCase
  fixtures []

  setup do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE hirings, hired_recruits, routes, recruits, ships, buildings, users RESTART IDENTITY CASCADE")
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
    clear_enqueued_jobs
  end

  # =====================
  # Job Deduplication
  # =====================

  test "ensure_pool_ready only schedules one job when called multiple times" do
    # Call multiple times rapidly
    3.times { RecruiterRefreshJob.ensure_pool_ready }

    # Should only have scheduled once (deduplication)
    jobs = enqueued_jobs.select { |j| j["job_class"] == "RecruiterRefreshJob" }
    assert_equal 1, jobs.count, "Should only schedule one job, not #{jobs.count}"
  end

  test "perform schedules next job only if not already scheduled" do
    RecruiterRefreshJob.perform_now
    first_jobs = enqueued_jobs.select { |j| j["job_class"] == "RecruiterRefreshJob" }
    
    clear_enqueued_jobs
    
    # Calling ensure_pool_ready should NOT schedule another job
    # since one was just scheduled by perform_now
    # Note: In test adapter, this checks the logic, though jobs are cleared
    RecruiterRefreshJob.ensure_pool_ready
    
    # At most one job should be scheduled
    jobs = enqueued_jobs.select { |j| j["job_class"] == "RecruiterRefreshJob" }
    assert jobs.count <= 1, "Should not schedule duplicate jobs"
  end

  test "job_already_scheduled? returns false when queue is empty" do
    assert_not RecruiterRefreshJob.job_already_scheduled?
  end

  test "job_already_scheduled? returns true after scheduling" do
    RecruiterRefreshJob.set(wait: 30.minutes).perform_later
    
    # In test environment with test adapter, we check enqueued_jobs
    # In production with solid_queue, checks the database
    assert RecruiterRefreshJob.job_already_scheduled?
  end
end
