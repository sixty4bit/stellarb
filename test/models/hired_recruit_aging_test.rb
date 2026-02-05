# frozen_string_literal: true

require "test_helper"

class HiredRecruitAgingTest < ActiveSupport::TestCase
  # ==========================================
  # Task stellarb-v63: Effectiveness Decay Formula
  # ==========================================

  # Young NPCs (under 80% lifespan) should have no decay
  test "effectiveness_modifier returns 1.0 for young NPCs" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 50,
      lifespan_days: 100
    )

    assert_equal 1.0, recruit.age_effectiveness_modifier
  end

  test "effectiveness_modifier returns 1.0 at exactly 79% lifespan" do
    recruit = HiredRecruit.new(
      race: "solari",
      npc_class: "navigator",
      skill: 70,
      chaos_factor: 30,
      age_days: 79,
      lifespan_days: 100
    )

    assert_equal 1.0, recruit.age_effectiveness_modifier
  end

  # Elderly NPCs (80-100% lifespan) should have gradual decay
  test "effectiveness_modifier starts decaying at 80% lifespan" do
    recruit = HiredRecruit.new(
      race: "krog",
      npc_class: "marine",
      skill: 60,
      chaos_factor: 25,
      age_days: 80,
      lifespan_days: 100
    )

    modifier = recruit.age_effectiveness_modifier
    assert modifier < 1.0, "Expected decay at 80%, got #{modifier}"
    assert modifier > 0.9, "Expected gradual decay, not steep. Got #{modifier}"
  end

  test "effectiveness decays progressively with age" do
    recruit = build_recruit_at_age_percent(80)
    mod_80 = recruit.age_effectiveness_modifier

    recruit = build_recruit_at_age_percent(90)
    mod_90 = recruit.age_effectiveness_modifier

    recruit = build_recruit_at_age_percent(95)
    mod_95 = recruit.age_effectiveness_modifier

    recruit = build_recruit_at_age_percent(100)
    mod_100 = recruit.age_effectiveness_modifier

    # Should decay progressively
    assert mod_90 < mod_80, "90% should have more decay than 80%"
    assert mod_95 < mod_90, "95% should have more decay than 90%"
    assert mod_100 < mod_95, "100% should have more decay than 95%"
  end

  # NPCs past their lifespan should have severe decay but not zero
  test "effectiveness_modifier for NPCs past lifespan" do
    recruit = HiredRecruit.new(
      race: "myrmidon",
      npc_class: "governor",
      skill: 80,
      chaos_factor: 15,
      age_days: 120,  # 20% past lifespan
      lifespan_days: 100
    )

    modifier = recruit.age_effectiveness_modifier
    assert modifier > 0, "Should not be zero even past lifespan"
    assert modifier < 0.7, "Should have significant decay past lifespan"
  end

  test "effectiveness_modifier never goes below minimum threshold" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 500,  # Way past lifespan
      lifespan_days: 100
    )

    modifier = recruit.age_effectiveness_modifier
    assert modifier >= 0.3, "Should have minimum effectiveness floor of 0.3, got #{modifier}"
  end

  # Combined effectiveness with quirks
  test "total_effectiveness combines quirks and age decay" do
    recruit = HiredRecruit.new(
      race: "solari",
      npc_class: "navigator",
      skill: 70,
      chaos_factor: 30,
      age_days: 90,  # 90% of lifespan
      lifespan_days: 100,
      stats: { "quirks" => ["efficient"] }  # +15%
    )

    age_mod = recruit.age_effectiveness_modifier
    quirk_mod = recruit.performance_modifier
    total = recruit.total_effectiveness

    # Total should be product of both modifiers
    expected = age_mod * quirk_mod
    assert_in_delta expected, total, 0.01
  end

  test "total_effectiveness for young NPC equals quirk modifier" do
    recruit = HiredRecruit.new(
      race: "krog",
      npc_class: "marine",
      skill: 60,
      chaos_factor: 25,
      age_days: 50,  # 50% of lifespan (young)
      lifespan_days: 100,
      stats: { "quirks" => ["lazy"] }  # -15%
    )

    # Age modifier should be 1.0 (young)
    # So total should equal quirk modifier
    assert_equal 1.0, recruit.age_effectiveness_modifier
    assert_in_delta recruit.performance_modifier, recruit.total_effectiveness, 0.01
  end

  test "total_effectiveness returns 1.0 for no quirks and young age" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 30,
      lifespan_days: 100,
      stats: { "quirks" => [] }
    )

    assert_equal 1.0, recruit.total_effectiveness
  end

  # Edge cases
  test "effectiveness_modifier handles nil lifespan" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 50,
      lifespan_days: nil
    )

    # Should return minimum (assume very old)
    assert_equal HiredRecruit::MINIMUM_EFFECTIVENESS, recruit.age_effectiveness_modifier
  end

  test "effectiveness_modifier handles zero lifespan" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: 50,
      lifespan_days: 0
    )

    # Should return minimum
    assert_equal HiredRecruit::MINIMUM_EFFECTIVENESS, recruit.age_effectiveness_modifier
  end

  test "effectiveness_modifier handles nil age_days" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: nil,
      lifespan_days: 100
    )

    # Should treat as brand new (0 age)
    assert_equal 1.0, recruit.age_effectiveness_modifier
  end

  private

  def build_recruit_at_age_percent(percent)
    lifespan = 100
    age = (lifespan * percent / 100.0).round

    HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      age_days: age,
      lifespan_days: lifespan
    )
  end
end
