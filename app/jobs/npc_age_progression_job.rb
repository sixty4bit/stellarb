# frozen_string_literal: true

# NPC Age Progression Job
#
# Runs daily to increment the age of all actively employed NPCs.
# Per ROADMAP Section 4.4.3: NPCs have a functional lifespan and
# "age increases daily".
#
# This job should be scheduled to run once per game-day.
# Use Solid Queue or cron to schedule: `NpcAgeProgressionJob.perform_later`
#
class NpcAgeProgressionJob < ApplicationJob
  queue_as :default

  # Perform the age progression
  #
  # @param days [Integer] Number of days to age (default: 1)
  #   Can be > 1 for catch-up after system downtime
  def perform(days: 1)
    # Find all HiredRecruits with at least one active hiring
    # Use a batch update for efficiency
    actively_employed_ids = Hiring
      .where(status: "active")
      .distinct
      .pluck(:hired_recruit_id)

    return if actively_employed_ids.empty?

    # Batch update all actively employed recruits
    HiredRecruit
      .where(id: actively_employed_ids)
      .update_all("age_days = age_days + #{days.to_i}")

    Rails.logger.info "[NpcAgeProgressionJob] Aged #{actively_employed_ids.size} NPCs by #{days} day(s)"
  end
end
