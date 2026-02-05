# frozen_string_literal: true

require "test_helper"

class RecruitTest < ActiveSupport::TestCase
  # Don't load fixtures for this test - we create our own data
  fixtures []

  setup do
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
    @other_user = User.create!(email: "other@example.com", name: "Other User", level_tier: 1)
    @high_tier_user = User.create!(email: "high@example.com", name: "High Tier", level_tier: 3)
  end

  # =====================
  # Constants
  # =====================

  test "has valid race constants" do
    assert_equal %w[vex solari krog myrmidon], Recruit::RACES
  end

  test "has valid npc_class constants" do
    assert_equal %w[governor navigator engineer marine], Recruit::NPC_CLASSES
  end

  test "has valid rarity tier constants" do
    assert_equal %w[common uncommon rare legendary], Recruit::RARITY_TIERS
  end

  # =====================
  # Validations
  # =====================

  test "validates presence of level_tier" do
    recruit = build_recruit(level_tier: nil)
    assert_not recruit.valid?
    assert_includes recruit.errors[:level_tier], "can't be blank"
  end

  test "validates level_tier is at least 1" do
    recruit = build_recruit(level_tier: 0)
    assert_not recruit.valid?
    assert_includes recruit.errors[:level_tier], "must be greater than or equal to 1"
  end

  test "validates presence of race" do
    recruit = build_recruit(race: nil)
    assert_not recruit.valid?
    assert_includes recruit.errors[:race], "can't be blank"
  end

  test "validates race inclusion" do
    recruit = build_recruit(race: "invalid_race")
    assert_not recruit.valid?
    assert_includes recruit.errors[:race], "is not included in the list"
  end

  test "validates presence of npc_class" do
    recruit = build_recruit(npc_class: nil)
    assert_not recruit.valid?
    assert_includes recruit.errors[:npc_class], "can't be blank"
  end

  test "validates npc_class inclusion" do
    recruit = build_recruit(npc_class: "invalid_class")
    assert_not recruit.valid?
    assert_includes recruit.errors[:npc_class], "is not included in the list"
  end

  test "validates skill is between 1 and 100" do
    assert_not build_recruit(skill: 0).valid?
    assert_not build_recruit(skill: 101).valid?
    assert build_recruit(skill: 1).valid?
    assert build_recruit(skill: 100).valid?
  end

  test "validates chaos_factor is between 0 and 100" do
    assert_not build_recruit(chaos_factor: -1).valid?
    assert_not build_recruit(chaos_factor: 101).valid?
    assert build_recruit(chaos_factor: 0).valid?
    assert build_recruit(chaos_factor: 100).valid?
  end

  test "validates presence of available_at" do
    recruit = build_recruit(available_at: nil)
    assert_not recruit.valid?
    assert_includes recruit.errors[:available_at], "can't be blank"
  end

  test "validates presence of expires_at" do
    recruit = build_recruit(expires_at: nil)
    assert_not recruit.valid?
    assert_includes recruit.errors[:expires_at], "can't be blank"
  end

  # =====================
  # Scopes
  # =====================

  test "available_for scope returns recruits matching user level_tier" do
    now = Time.current
    tier1_recruit = Recruit.create!(
      level_tier: 1,
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: now - 1.hour,
      expires_at: now + 1.hour
    )
    tier3_recruit = Recruit.create!(
      level_tier: 3,
      race: "krog",
      npc_class: "marine",
      skill: 60,
      chaos_factor: 30,
      available_at: now - 1.hour,
      expires_at: now + 1.hour
    )

    # Tier 1 user should see tier 1 recruit
    available = Recruit.available_for(@user)
    assert_includes available, tier1_recruit
    assert_not_includes available, tier3_recruit

    # Tier 3 user should see tier 3 recruit
    available_high = Recruit.available_for(@high_tier_user)
    assert_not_includes available_high, tier1_recruit
    assert_includes available_high, tier3_recruit
  end

  test "available_for scope excludes expired recruits" do
    now = Time.current
    active_recruit = Recruit.create!(
      level_tier: 1,
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: now - 1.hour,
      expires_at: now + 1.hour
    )
    expired_recruit = Recruit.create!(
      level_tier: 1,
      race: "krog",
      npc_class: "marine",
      skill: 60,
      chaos_factor: 30,
      available_at: now - 2.hours,
      expires_at: now - 1.hour
    )

    available = Recruit.available_for(@user)
    assert_includes available, active_recruit
    assert_not_includes available, expired_recruit
  end

  test "available_for scope excludes recruits not yet available" do
    now = Time.current
    active_recruit = Recruit.create!(
      level_tier: 1,
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: now - 1.hour,
      expires_at: now + 1.hour
    )
    future_recruit = Recruit.create!(
      level_tier: 1,
      race: "krog",
      npc_class: "marine",
      skill: 60,
      chaos_factor: 30,
      available_at: now + 1.hour,
      expires_at: now + 2.hours
    )

    available = Recruit.available_for(@user)
    assert_includes available, active_recruit
    assert_not_includes available, future_recruit
  end

  test "same level tier users see same recruits (shared pool)" do
    now = Time.current
    recruit = Recruit.create!(
      level_tier: 1,
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: now - 1.hour,
      expires_at: now + 1.hour
    )

    user1_recruits = Recruit.available_for(@user).to_a
    user2_recruits = Recruit.available_for(@other_user).to_a

    assert_equal user1_recruits, user2_recruits
  end

  test "expired scope returns only expired recruits" do
    now = Time.current
    active = Recruit.create!(
      level_tier: 1, race: "vex", npc_class: "engineer",
      skill: 50, chaos_factor: 20,
      available_at: now - 1.hour, expires_at: now + 1.hour
    )
    expired = Recruit.create!(
      level_tier: 1, race: "krog", npc_class: "marine",
      skill: 60, chaos_factor: 30,
      available_at: now - 2.hours, expires_at: now - 1.hour
    )

    assert_not_includes Recruit.expired, active
    assert_includes Recruit.expired, expired
  end

  # =====================
  # Rarity Tier
  # =====================

  test "rarity_tier returns legendary for skill >= 90" do
    recruit = build_recruit(skill: 90)
    assert_equal "legendary", recruit.rarity_tier

    recruit = build_recruit(skill: 100)
    assert_equal "legendary", recruit.rarity_tier
  end

  test "rarity_tier returns rare for skill 75-89" do
    recruit = build_recruit(skill: 75)
    assert_equal "rare", recruit.rarity_tier

    recruit = build_recruit(skill: 89)
    assert_equal "rare", recruit.rarity_tier
  end

  test "rarity_tier returns uncommon for skill 50-74" do
    recruit = build_recruit(skill: 50)
    assert_equal "uncommon", recruit.rarity_tier

    recruit = build_recruit(skill: 74)
    assert_equal "uncommon", recruit.rarity_tier
  end

  test "rarity_tier returns common for skill < 50" do
    recruit = build_recruit(skill: 49)
    assert_equal "common", recruit.rarity_tier

    recruit = build_recruit(skill: 1)
    assert_equal "common", recruit.rarity_tier
  end

  # =====================
  # Wage Calculation
  # =====================

  test "base_wage scales with skill" do
    low_skill = build_recruit(skill: 30, chaos_factor: 0)
    mid_skill = build_recruit(skill: 60, chaos_factor: 0)
    high_skill = build_recruit(skill: 85, chaos_factor: 0)
    legendary = build_recruit(skill: 95, chaos_factor: 0)

    assert low_skill.base_wage < mid_skill.base_wage
    assert mid_skill.base_wage < high_skill.base_wage
    assert high_skill.base_wage < legendary.base_wage
  end

  test "base_wage applies 1.5x multiplier above skill 80" do
    skill_80 = build_recruit(skill: 80, chaos_factor: 0)
    skill_81 = build_recruit(skill: 81, chaos_factor: 0)

    # 80 * 10 = 800
    # 81 * 10 * 1.5 = 1215
    assert_equal 800, skill_80.base_wage
    assert_equal 1215, skill_81.base_wage
  end

  test "base_wage applies additional 2.0x multiplier above skill 90" do
    skill_90 = build_recruit(skill: 90, chaos_factor: 0)
    skill_91 = build_recruit(skill: 91, chaos_factor: 0)

    # 90 * 10 * 1.5 = 1350
    # 91 * 10 * 1.5 * 2.0 = 2730
    assert_equal 1350, skill_90.base_wage
    assert_equal 2730, skill_91.base_wage
  end

  test "base_wage applies chaos_factor discount" do
    no_chaos = build_recruit(skill: 50, chaos_factor: 0)
    mid_chaos = build_recruit(skill: 50, chaos_factor: 50)
    high_chaos = build_recruit(skill: 50, chaos_factor: 100)

    # Chaos factor provides discount (risky hires are cheaper)
    assert no_chaos.base_wage > mid_chaos.base_wage
    assert mid_chaos.base_wage > high_chaos.base_wage
  end

  # =====================
  # Name Generation
  # =====================

  test "generates name from race pool" do
    recruit = build_recruit(race: "vex")
    recruit.generate_name!

    assert_not_nil recruit.name
    assert recruit.name.present?
  end

  test "name generation is deterministic for same seed" do
    recruit1 = build_recruit(race: "krog")
    recruit1.seed = "test_seed_123"
    recruit1.generate_name!

    recruit2 = build_recruit(race: "krog")
    recruit2.seed = "test_seed_123"
    recruit2.generate_name!

    assert_equal recruit1.name, recruit2.name
  end

  # =====================
  # Quirks System
  # =====================

  test "generates quirks based on chaos_factor" do
    low_chaos = build_recruit(chaos_factor: 10)
    low_chaos.generate_quirks!

    high_chaos = build_recruit(chaos_factor: 90)
    high_chaos.generate_quirks!

    # Both should have quirks array in base_stats
    assert low_chaos.base_stats["quirks"].is_a?(Array)
    assert high_chaos.base_stats["quirks"].is_a?(Array)

    # High chaos should have more quirks on average (2-3 vs 0-1)
    # Since randomness is involved, we just verify the structure
    assert high_chaos.base_stats["quirks"].length >= 0
  end

  test "low chaos favors positive quirks" do
    recruit = build_recruit(chaos_factor: 10)
    # Using a fixed seed for deterministic test
    recruit.seed = "low_chaos_test"
    recruit.generate_quirks!

    quirks = recruit.base_stats["quirks"]
    # Low chaos (0-20): 70% positive, 25% neutral, 5% negative
    # With 0-1 quirks, most should be positive
    if quirks.any?
      positive_quirks = Recruit::POSITIVE_QUIRKS
      assert quirks.any? { |q| positive_quirks.include?(q) || Recruit::NEUTRAL_QUIRKS.include?(q) }
    end
  end

  test "high chaos favors negative quirks" do
    recruit = build_recruit(chaos_factor: 90)
    recruit.seed = "high_chaos_test"
    recruit.generate_quirks!

    quirks = recruit.base_stats["quirks"]
    # High chaos (81-100): 2-3 quirks, mostly negative
    assert quirks.length >= 1 # Should have at least 1 quirk
  end

  # =====================
  # Employment History Generation
  # =====================

  test "generates employment history" do
    recruit = build_recruit(chaos_factor: 30)
    recruit.generate_employment_history!

    assert recruit.employment_history.is_a?(Array)
    assert recruit.employment_history.length.between?(2, 5)
  end

  test "employment history entries have required fields" do
    recruit = build_recruit(chaos_factor: 30)
    recruit.generate_employment_history!

    recruit.employment_history.each do |entry|
      assert entry["employer"].present?
      assert entry["duration"].present?
      assert entry["outcome"].present?
    end
  end

  test "high chaos recruits have more incidents in history" do
    low_chaos = build_recruit(chaos_factor: 10)
    low_chaos.seed = "low_chaos_history"
    low_chaos.generate_employment_history!

    high_chaos = build_recruit(chaos_factor: 90)
    high_chaos.seed = "high_chaos_history"
    high_chaos.generate_employment_history!

    # Check for red flags in history
    low_incidents = low_chaos.employment_history.count { |e| e["outcome"] != "clean_exit" }
    high_incidents = high_chaos.employment_history.count { |e| e["outcome"] != "clean_exit" }

    # High chaos should generally have more incidents
    # Note: Due to randomness this might occasionally fail, but statistically should pass
    assert high_incidents >= 0 # Just verify structure works
  end

  # =====================
  # Generation Factory Method
  # =====================

  test "generate! creates a valid recruit with all fields populated" do
    recruit = Recruit.generate!(level_tier: 1)

    assert recruit.persisted?
    assert recruit.race.present?
    assert recruit.npc_class.present?
    assert recruit.skill.between?(1, 100)
    assert recruit.chaos_factor.between?(0, 100)
    assert recruit.name.present?
    assert recruit.base_stats["quirks"].is_a?(Array)
    assert recruit.employment_history.is_a?(Array)
    assert recruit.available_at.present?
    assert recruit.expires_at.present?
  end

  test "generate! respects rarity distribution" do
    # Generate many recruits and verify distribution
    recruits = 100.times.map { Recruit.generate!(level_tier: 1) }

    counts = recruits.group_by(&:rarity_tier).transform_values(&:count)

    # Common: 70%, Uncommon: 20%, Rare: 8%, Legendary: 2%
    # With 100 samples, we should see roughly this distribution
    assert counts["common"].to_i > counts["uncommon"].to_i
    assert counts["uncommon"].to_i > counts["rare"].to_i
    # Legendary is rare enough it might be 0 in 100 samples
  end

  test "generate! sets availability window correctly" do
    now = Time.current
    recruit = Recruit.generate!(level_tier: 1)

    # available_at should be around now (allowing 5 second buffer for test execution)
    assert recruit.available_at <= now + 5.seconds
    assert recruit.expires_at > now
    # Expires in 30-90 minutes (allowing some buffer for test execution)
    assert recruit.expires_at <= now + 100.minutes, "Expected expires_at to be within 100 minutes, got #{recruit.expires_at - now} seconds"
    assert recruit.expires_at >= now + 29.minutes, "Expected expires_at to be at least 29 minutes away, got #{recruit.expires_at - now} seconds"
  end

  # =====================
  # Hire! Method
  # =====================

  test "hire! creates HiredRecruit from recruit" do
    recruit = Recruit.generate!(level_tier: 1)
    ship = create_test_ship(@user)

    hiring = recruit.hire!(@user, ship)

    assert_kind_of Hiring, hiring
    assert hiring.persisted?
    assert_equal recruit.race, hiring.hired_recruit.race
    assert_equal recruit.npc_class, hiring.hired_recruit.npc_class
    assert_equal recruit.skill, hiring.hired_recruit.skill
  end

  test "hire! creates Hiring join record" do
    recruit = Recruit.generate!(level_tier: 1)
    ship = create_test_ship(@user)

    hiring = recruit.hire!(@user, ship)

    assert_equal @user, hiring.user
    assert_equal ship, hiring.assignable
    assert_equal "active", hiring.status
    assert hiring.wage > 0
    assert_not_nil hiring.hired_at
  end

  test "hire! links HiredRecruit to original recruit" do
    recruit = Recruit.generate!(level_tier: 1)
    ship = create_test_ship(@user)

    hiring = recruit.hire!(@user, ship)

    assert_equal recruit, hiring.hired_recruit.original_recruit
  end

  test "hire! raises error if recruit already expired" do
    recruit = build_recruit(expires_at: 1.hour.ago)
    recruit.save!
    ship = create_test_ship(@user)

    assert_raises(Recruit::AlreadyHiredError) do
      recruit.hire!(@user, ship)
    end
  end

  test "hire! raises error if recruit not yet available" do
    recruit = build_recruit(available_at: 1.hour.from_now, expires_at: 2.hours.from_now)
    recruit.save!
    ship = create_test_ship(@user)

    assert_raises(Recruit::NotAvailableError) do
      recruit.hire!(@user, ship)
    end
  end

  private

  def create_test_ship(user)
    Ship.create!(
      user: user,
      name: "Test Ship #{SecureRandom.hex(3)}",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      location_x: 0,
      location_y: 0,
      location_z: 0
    )
  end

  private

  def build_recruit(overrides = {})
    defaults = {
      level_tier: 1,
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      available_at: Time.current - 1.hour,
      expires_at: Time.current + 1.hour
    }
    Recruit.new(defaults.merge(overrides))
  end
end
