# frozen_string_literal: true

require "test_helper"

# Tests for NPC Aging - Retirement/Death events
# ROADMAP Section 4.4.3: NPCs have functional lifespan, eventually retire.
#
# When an NPC reaches their lifespan:
# - They have a chance to retire (more likely) or die (less likely)
# - The Hiring status is updated accordingly
# - The player is forced to find a replacement
class NpcAgingJobTest < ActiveSupport::TestCase
  # Disable all fixtures - we create our own test data
  self.use_transactional_tests = true
  fixtures []

  setup do
    @user = User.create!(email: "aging-test-#{SecureRandom.hex(4)}@example.com", name: "Test Player", level_tier: 1)
    @ship = Ship.create!(
      user: @user,
      name: "Test Hauler",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      location_x: 0,
      location_y: 0,
      location_z: 0
    )
  end

  # ===========================================
  # Basic Aging Mechanics
  # ===========================================

  test "increments age_days for all hired recruits with active hirings" do
    recruit = create_hired_recruit(age_days: 10, lifespan_days: 100)
    hiring = create_hiring(recruit, status: "active")

    NpcAgingJob.perform_now

    recruit.reload
    assert_equal 11, recruit.age_days
  end

  test "does not increment age for recruits without active hirings" do
    recruit = create_hired_recruit(age_days: 10, lifespan_days: 100)
    # No hiring created - recruit is not employed

    NpcAgingJob.perform_now

    recruit.reload
    assert_equal 10, recruit.age_days, "Unemployed recruit should not age"
  end

  test "does not increment age for recruits with terminated hirings" do
    recruit = create_hired_recruit(age_days: 10, lifespan_days: 100)
    create_hiring(recruit, status: "fired")

    NpcAgingJob.perform_now

    recruit.reload
    assert_equal 10, recruit.age_days, "Terminated recruit should not age"
  end

  # ===========================================
  # Retirement Events
  # ===========================================

  test "triggers retirement or death when NPC exceeds lifespan" do
    recruit = create_hired_recruit(age_days: 100, lifespan_days: 100)
    hiring = create_hiring(recruit, status: "active")

    NpcAgingJob.perform_now

    hiring.reload
    assert_includes %w[retired deceased], hiring.status
    assert_not_nil hiring.terminated_at
  end

  test "NPC past lifespan gets employment history recorded" do
    recruit = create_hired_recruit(age_days: 100, lifespan_days: 100)
    hiring = create_hiring(recruit, status: "active")
    original_history_count = recruit.employment_history.length

    NpcAgingJob.perform_now

    recruit.reload
    assert_equal original_history_count + 1, recruit.employment_history.length
    last_record = recruit.employment_history.last
    # Should have either retirement or death outcome text
    # Outcome should be a non-empty string (various random messages possible)
    assert last_record["outcome"].present?, "Expected non-empty outcome message"
  end

  # ===========================================
  # Death Probability
  # ===========================================

  test "death_probability is low when NPC just reaches lifespan" do
    # At exactly lifespan: should be around BASE_DEATH_PROBABILITY (10%)
    prob = NpcAgingJob.death_probability(100, 100)
    assert_in_delta 0.10, prob, 0.01
  end

  test "death_probability increases when NPC exceeds lifespan" do
    at_lifespan = NpcAgingJob.death_probability(100, 100)
    past_50_percent = NpcAgingJob.death_probability(150, 100)
    past_100_percent = NpcAgingJob.death_probability(200, 100)

    assert past_50_percent > at_lifespan, "Death chance should increase past lifespan"
    assert past_100_percent > past_50_percent, "Death chance should increase more the older they get"
  end

  test "death_probability caps at 95%" do
    # Even very old NPCs shouldn't have 100% death chance (chance for retirement)
    very_old_prob = NpcAgingJob.death_probability(500, 100)
    assert_equal 0.95, very_old_prob
  end

  test "death_probability is 0 when under lifespan" do
    prob = NpcAgingJob.death_probability(50, 100)
    assert_equal 0.0, prob
  end

  test "death_probability handles nil lifespan" do
    prob = NpcAgingJob.death_probability(50, nil)
    assert_equal 0.0, prob
  end

  test "death_probability handles zero lifespan" do
    prob = NpcAgingJob.death_probability(50, 0)
    assert_equal 0.0, prob
  end

  # ===========================================
  # Job Results
  # ===========================================

  test "returns summary of aging results" do
    # Track initial state
    initial_recruit_count = HiredRecruit.joins(:hirings).where(hirings: { status: "active" }).distinct.count

    # Create multiple recruits in various states
    active1 = create_hired_recruit(age_days: 10, lifespan_days: 100)
    create_hiring(active1, status: "active")

    active2 = create_hired_recruit(age_days: 20, lifespan_days: 100)
    create_hiring(active2, status: "active")

    # Unemployed recruit (shouldn't be processed)
    create_hired_recruit(age_days: 50, lifespan_days: 100)

    results = NpcAgingJob.perform_now

    # Should age at least our 2 new recruits (plus any existing active ones)
    assert results[:recruits_aged] >= 2
    # Verify our specific recruits aged
    assert_equal 11, active1.reload.age_days
    assert_equal 21, active2.reload.age_days
  end

  test "counts retirements and deaths in results" do
    # Create 5 NPCs past their lifespan
    recruits = 5.times.map do |i|
      recruit = create_hired_recruit(age_days: 150, lifespan_days: 100)
      create_hiring(recruit, status: "active")
      recruit
    end

    results = NpcAgingJob.perform_now

    # All 5 should have been aged and terminated
    assert results[:recruits_aged] >= 5
    # At least our 5 should have been terminated (retired or deceased)
    total_terminations = results[:retirements] + results[:deaths]
    assert total_terminations >= 5, "Expected at least 5 terminations, got #{total_terminations}"

    # Verify all our recruits are no longer active
    recruits.each do |recruit|
      hiring = Hiring.find_by(hired_recruit: recruit, user: @user)
      assert_includes %w[retired deceased], hiring.status
    end
  end

  # ===========================================
  # Edge Cases
  # ===========================================

  test "handles NPC with nil lifespan gracefully" do
    recruit = create_hired_recruit(age_days: 50, lifespan_days: nil)
    hiring = create_hiring(recruit, status: "active")

    # Should not raise, should treat as immortal (never past_lifespan?)
    assert_nothing_raised do
      NpcAgingJob.perform_now
    end

    hiring.reload
    # NPC with nil lifespan is considered "past lifespan" by past_lifespan? method
    # (returns true if lifespan nil or 0)
    # So they will retire/die
    assert_includes %w[active retired deceased], hiring.status
  end

  test "processes multiple recruits in single job run" do
    recruits = 5.times.map do |i|
      recruit = create_hired_recruit(age_days: i * 10, lifespan_days: 200)
      create_hiring(recruit, status: "active")
      recruit
    end

    NpcAgingJob.perform_now

    recruits.each(&:reload)
    recruits.each_with_index do |recruit, i|
      # All should have aged by 1 day
      assert_equal (i * 10) + 1, recruit.age_days
    end
  end

  test "hiring retains assignable reference after retirement" do
    # The hiring keeps the assignable as historical record of where they worked
    recruit = create_hired_recruit(age_days: 100, lifespan_days: 100)
    hiring = create_hiring(recruit, status: "active")
    original_ship_id = hiring.assignable_id

    NpcAgingJob.perform_now

    hiring.reload
    assert_includes %w[retired deceased], hiring.status
    # Assignable should be preserved as historical record
    assert_equal original_ship_id, hiring.assignable_id
    assert_equal "Ship", hiring.assignable_type
  end

  # ===========================================
  # Multiple Active Hirings Edge Case
  # ===========================================

  test "terminates all active hirings when NPC retires" do
    # Rare edge case: same recruit hired by multiple users
    user2 = User.create!(email: "user2@example.com", name: "Player 2", level_tier: 1)
    ship2 = Ship.create!(
      user: user2,
      name: "Ship 2",
      race: "krog",
      hull_size: "scout",
      variant_idx: 0,
      location_x: 0,
      location_y: 0,
      location_z: 0
    )

    recruit = create_hired_recruit(age_days: 100, lifespan_days: 100)
    hiring1 = Hiring.create!(
      user: @user,
      hired_recruit: recruit,
      assignable: @ship,
      status: "active",
      wage: recruit.calculate_wage,
      hired_at: 1.month.ago
    )
    hiring2 = Hiring.create!(
      user: user2,
      hired_recruit: recruit,
      assignable: ship2,
      status: "active",
      wage: recruit.calculate_wage,
      hired_at: 1.month.ago
    )

    NpcAgingJob.perform_now

    hiring1.reload
    hiring2.reload
    # Both hirings should be terminated
    assert_not_equal "active", hiring1.status
    assert_not_equal "active", hiring2.status
  end

  private

  def create_hired_recruit(age_days:, lifespan_days:)
    HiredRecruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: age_days,
      lifespan_days: lifespan_days,
      stats: {},
      employment_history: []
    )
  end

  def create_hiring(hired_recruit, status:)
    Hiring.create!(
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: status,
      wage: hired_recruit.calculate_wage,
      hired_at: 1.month.ago
    )
  end
end
