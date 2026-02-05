# frozen_string_literal: true

require "test_helper"

class NpcAgeProgressionJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
    @ship = Ship.create!(
      user: @user,
      name: "Test Ship",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      location_x: 0,
      location_y: 0,
      location_z: 0
    )
  end

  # ==========================================
  # Task stellarb-4d9: Age Progression Job
  # ==========================================

  test "increments age_days for all hired recruits" do
    # Create two hired recruits with active hirings
    recruit1 = HiredRecruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 10,
      lifespan_days: 100
    )
    recruit2 = HiredRecruit.create!(
      race: "solari",
      npc_class: "navigator",
      skill: 70,
      chaos_factor: 30,
      age_days: 25,
      lifespan_days: 120
    )

    # Create active hirings
    Hiring.create!(
      user: @user,
      hired_recruit: recruit1,
      assignable: @ship,
      status: "active",
      wage: recruit1.calculate_wage,
      hired_at: Time.current
    )
    Hiring.create!(
      user: @user,
      hired_recruit: recruit2,
      assignable: @ship,
      status: "active",
      wage: recruit2.calculate_wage,
      hired_at: Time.current
    )

    # Run the job
    NpcAgeProgressionJob.perform_now

    # Verify ages increased by 1
    assert_equal 11, recruit1.reload.age_days
    assert_equal 26, recruit2.reload.age_days
  end

  test "only ages recruits with active hirings" do
    # Create two hired recruits
    active_recruit = HiredRecruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 10,
      lifespan_days: 100
    )
    inactive_recruit = HiredRecruit.create!(
      race: "krog",
      npc_class: "marine",
      skill: 60,
      chaos_factor: 40,
      age_days: 15,
      lifespan_days: 80
    )

    # Create active hiring for one, fired for another
    Hiring.create!(
      user: @user,
      hired_recruit: active_recruit,
      assignable: @ship,
      status: "active",
      wage: active_recruit.calculate_wage,
      hired_at: Time.current
    )
    Hiring.create!(
      user: @user,
      hired_recruit: inactive_recruit,
      assignable: @ship,
      status: "fired",
      wage: inactive_recruit.calculate_wage,
      hired_at: 1.day.ago,
      terminated_at: Time.current
    )

    # Run the job
    NpcAgeProgressionJob.perform_now

    # Only active recruit should age
    assert_equal 11, active_recruit.reload.age_days
    assert_equal 15, inactive_recruit.reload.age_days
  end

  test "does not age recruits without any hirings" do
    unhired_recruit = HiredRecruit.create!(
      race: "myrmidon",
      npc_class: "governor",
      skill: 40,
      chaos_factor: 50,
      age_days: 5,
      lifespan_days: 90
    )

    # No hiring created

    NpcAgeProgressionJob.perform_now

    # Should not age
    assert_equal 5, unhired_recruit.reload.age_days
  end

  test "can specify custom increment days" do
    recruit = HiredRecruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 10,
      lifespan_days: 100
    )
    Hiring.create!(
      user: @user,
      hired_recruit: recruit,
      assignable: @ship,
      status: "active",
      wage: recruit.calculate_wage,
      hired_at: Time.current
    )

    # Run with custom increment (e.g., for catch-up after downtime)
    NpcAgeProgressionJob.perform_now(days: 5)

    assert_equal 15, recruit.reload.age_days
  end

  test "handles empty database gracefully" do
    # No recruits exist
    assert_nothing_raised do
      NpcAgeProgressionJob.perform_now
    end
  end

  test "job is idempotent when run multiple times" do
    recruit = HiredRecruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 10,
      lifespan_days: 100
    )
    Hiring.create!(
      user: @user,
      hired_recruit: recruit,
      assignable: @ship,
      status: "active",
      wage: recruit.calculate_wage,
      hired_at: Time.current
    )

    # Run job twice (should be once per game day, but testing multiple runs)
    NpcAgeProgressionJob.perform_now
    NpcAgeProgressionJob.perform_now

    # Each run increments by 1
    assert_equal 12, recruit.reload.age_days
  end

  test "uses efficient batch update for performance" do
    # Create many recruits
    30.times do |i|
      recruit = HiredRecruit.create!(
        race: HiredRecruit::RACES.sample,
        npc_class: HiredRecruit::NPC_CLASSES.sample,
        skill: rand(1..100),
        chaos_factor: rand(0..100),
        age_days: i,
        lifespan_days: 100
      )
      Hiring.create!(
        user: @user,
        hired_recruit: recruit,
        assignable: @ship,
        status: "active",
        wage: recruit.calculate_wage,
        hired_at: Time.current
      )
    end

    # Track query count
    query_count = 0
    callback = lambda { |*| query_count += 1 }
    ActiveSupport::Notifications.subscribe("sql.active_record", callback)

    NpcAgeProgressionJob.perform_now

    ActiveSupport::Notifications.unsubscribe(callback)

    # Should use batch update, not N individual updates
    # Allowing some queries for setup/cleanup but should be << 30
    assert query_count < 15, "Expected batch update but got #{query_count} queries"
  end
end
