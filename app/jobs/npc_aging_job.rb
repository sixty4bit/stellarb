# frozen_string_literal: true

# Daily job that ages NPCs and triggers retirement/death events.
# Implements ROADMAP Section 4.4.3 - NPC Aging & Decay.
#
# When an NPC exceeds their lifespan:
# - They have a chance to retire (more common) or die (less common)
# - Death probability increases the more they exceed their lifespan
# - The Hiring status is updated to 'retired' or 'deceased'
# - The NPC is unassigned from their ship/building
# - An employment record is added to their history
class NpcAgingJob < ApplicationJob
  queue_as :default

  # Base death probability when NPC first exceeds lifespan (10%)
  BASE_DEATH_PROBABILITY = 0.10

  # How much death probability increases per 10% past lifespan
  # At 150% lifespan: 10% + (50% * 0.8) = 50%
  # At 200% lifespan: 10% + (100% * 0.8) = 90%
  DEATH_PROBABILITY_SCALING = 0.008

  class << self
    # Calculate probability of death based on how far past lifespan
    # Returns a value between 0.0 and 1.0
    def death_probability(age_days, lifespan_days)
      return 0.0 if lifespan_days.nil? || lifespan_days <= 0
      return 0.0 if age_days < lifespan_days

      # How much past lifespan (as percentage, e.g., 150 vs 100 = 50)
      overage_percent = ((age_days - lifespan_days).to_f / lifespan_days) * 100

      # Scale probability based on overage
      probability = BASE_DEATH_PROBABILITY + (overage_percent * DEATH_PROBABILITY_SCALING)

      # Clamp to valid probability range
      probability.clamp(0.0, 0.95)
    end

    # Roll for death based on probability
    def should_die?(age_days, lifespan_days)
      rand < death_probability(age_days, lifespan_days)
    end
  end

  def perform
    results = {
      recruits_aged: 0,
      retirements: 0,
      deaths: 0
    }

    # Find all hired recruits with active hirings
    # We only age NPCs who are currently employed
    actively_employed_recruits.find_each do |recruit|
      # Increment age
      recruit.increment!(:age_days)
      results[:recruits_aged] += 1

      # Check if past lifespan and should trigger retirement/death
      if recruit.past_lifespan?
        result = process_end_of_life(recruit)
        results[:retirements] += 1 if result == :retired
        results[:deaths] += 1 if result == :deceased
      end
    end

    results
  end

  private

  # Find all hired recruits that have at least one active hiring
  def actively_employed_recruits
    HiredRecruit.joins(:hirings)
                .where(hirings: { status: "active" })
                .distinct
  end

  # Process retirement or death for an NPC past their lifespan
  # Returns :retired or :deceased based on outcome
  def process_end_of_life(recruit)
    # Roll for death (probability increases with age past lifespan)
    outcome = if self.class.should_die?(recruit.age_days, recruit.lifespan_days)
      :deceased
    else
      :retired
    end

    # Terminate all active hirings for this recruit
    recruit.hirings.active.each do |hiring|
      terminate_hiring(hiring, outcome, recruit)
    end

    outcome
  end

  # Terminate a hiring with the appropriate status and record history
  def terminate_hiring(hiring, outcome, recruit)
    # Calculate employment duration for history
    duration_months = calculate_duration_months(hiring)

    # Generate outcome text for employment history
    outcome_text = case outcome
    when :deceased
      generate_death_outcome(recruit)
    when :retired
      generate_retirement_outcome(recruit)
    end

    # Add to employment history
    recruit.add_employment_record(
      employer: hiring.user.name,
      duration_months: duration_months,
      outcome: outcome_text
    )

    # Terminate hiring (keep assignable as historical record of where they worked)
    # The status change to retired/deceased indicates they're no longer active
    hiring.update!(
      status: outcome.to_s,
      terminated_at: Time.current
    )
  end

  # Calculate employment duration in months
  def calculate_duration_months(hiring)
    return 1 unless hiring.hired_at

    months = ((Time.current - hiring.hired_at) / 1.month).round
    [months, 1].max # Minimum 1 month
  end

  # Generate a death outcome message based on NPC traits
  def generate_death_outcome(recruit)
    death_messages = [
      "Deceased (natural causes)",
      "Died peacefully",
      "Passed away",
      "Death (age-related)",
      "Deceased while on duty"
    ]

    # Racial flavor
    racial_messages = case recruit.race
    when "vex"
      ["Died counting profits", "Passed away mid-negotiation", "Deceased (suspected stress)"]
    when "solari"
      ["System shutdown (permanent)", "Logic circuits failed", "Terminated (hardware failure)"]
    when "krog"
      ["Died gloriously (of old age)", "Fell in battle (with time)", "Crushed by the weight of years"]
    when "myrmidon"
      ["Returned to the hive", "Drone decommissioned", "Recycled by collective"]
    else
      []
    end

    (death_messages + racial_messages).sample
  end

  # Generate a retirement outcome message
  def generate_retirement_outcome(recruit)
    retirement_messages = [
      "Retired honorably",
      "Voluntary retirement",
      "Retired (age)",
      "Retired to pursue other interests"
    ]

    # Racial flavor
    racial_messages = case recruit.race
    when "vex"
      ["Retired to count money", "Left to manage investments", "Retired (golden parachute)"]
    when "solari"
      ["Entered low-power mode", "Retired for system maintenance", "Archived"]
    when "krog"
      ["Retired to tell war stories", "Left to train younglings", "Honorable discharge"]
    when "myrmidon"
      ["Reassigned to nursery duty", "Retired to egg-tending", "Promoted to elder cluster"]
    else
      []
    end

    (retirement_messages + racial_messages).sample
  end
end
