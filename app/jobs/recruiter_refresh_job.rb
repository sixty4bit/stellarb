# frozen_string_literal: true

class RecruiterRefreshJob < ApplicationJob
  queue_as :default

  # Pool size calculation: (active_players * 0.3) per class, minimum 10 per class
  MIN_PER_CLASS = 10
  POOL_MULTIPLIER = 0.3

  # Check if a RecruiterRefreshJob is already scheduled
  # Works with both test adapter and solid_queue
  def self.job_already_scheduled?
    if Rails.env.test?
      # Test adapter stores jobs in memory
      ActiveJob::Base.queue_adapter.enqueued_jobs.any? do |job|
        job["job_class"] == "RecruiterRefreshJob"
      end
    elsif defined?(SolidQueue)
      # Check solid_queue scheduled jobs
      SolidQueue::ScheduledExecution
        .where(job_class: "RecruiterRefreshJob")
        .exists?
    else
      false
    end
  end

  # Idempotent startup method - safe to call on every server boot
  # Checks pool health, refreshes if needed, ensures job is scheduled
  def self.ensure_pool_ready
    job = new
    job.send(:cleanup_expired_recruits)

    if Recruit.pool_needs_refresh?
      # Pool is empty or stale, generate fresh recruits
      job.send(:active_tiers).each do |tier|
        job.send(:generate_pool_for_tier, tier)
      end
    end

    # Only schedule if not already scheduled (deduplication)
    job.send(:schedule_next_run) unless job_already_scheduled?
  end

  def perform
    # Step 1: Clean up expired recruits
    cleanup_expired_recruits

    # Step 2: Generate new recruits for each tier
    active_tiers.each do |tier|
      generate_pool_for_tier(tier)
    end

    # Step 3: Reschedule for next rotation (30-90 minutes)
    schedule_next_run
  end

  private

  def cleanup_expired_recruits
    Recruit.expired.delete_all
  end

  def active_tiers
    User.distinct.pluck(:level_tier).compact
  end

  def generate_pool_for_tier(tier)
    active_players = User.where(level_tier: tier).count
    target_per_class = calculate_target_per_class(active_players)

    Recruit::NPC_CLASSES.each do |npc_class|
      current_count = Recruit.available_for_tier(tier).where(npc_class: npc_class).count
      needed = target_per_class - current_count

      next unless needed > 0

      needed.times do
        Recruit.generate!(level_tier: tier, npc_class: npc_class)
      end
    end
  end

  def calculate_target_per_class(active_players)
    calculated = (active_players * POOL_MULTIPLIER).ceil
    [ calculated, MIN_PER_CLASS ].max
  end

  def schedule_next_run
    return if self.class.job_already_scheduled?

    delay_minutes = rand(30..90)
    RecruiterRefreshJob.set(wait: delay_minutes.minutes).perform_later
  end
end
