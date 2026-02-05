# frozen_string_literal: true

require "test_helper"

class HiredRecruitTest < ActiveSupport::TestCase
  fixtures []

  setup do
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
    @recruit = Recruit.generate!(level_tier: 1)
  end

  # =====================
  # create_from_recruit!
  # =====================

  test "create_from_recruit! creates immutable copy of recruit attributes" do
    hired = HiredRecruit.create_from_recruit!(@recruit, @user)

    assert hired.persisted?
    assert_equal @recruit.race, hired.race
    assert_equal @recruit.npc_class, hired.npc_class
    assert_equal @recruit.skill, hired.skill
    assert_equal @recruit.chaos_factor, hired.chaos_factor
  end

  test "create_from_recruit! links to original recruit" do
    hired = HiredRecruit.create_from_recruit!(@recruit, @user)

    assert_equal @recruit, hired.original_recruit
  end

  test "create_from_recruit! deep copies base_stats" do
    @recruit.update!(base_stats: { "quirks" => [ "efficient", "loyal" ] })
    hired = HiredRecruit.create_from_recruit!(@recruit, @user)

    # Verify deep copy
    assert_equal @recruit.base_stats["quirks"], hired.stats["quirks"]

    # Verify mutation doesn't affect original
    hired.stats["quirks"] << "test"
    @recruit.reload
    assert_not_includes @recruit.base_stats["quirks"], "test"
  end

  test "create_from_recruit! deep copies employment_history" do
    hired = HiredRecruit.create_from_recruit!(@recruit, @user)

    assert_equal @recruit.employment_history.length, hired.employment_history.length

    # Verify mutation doesn't affect original
    hired.employment_history << { "employer" => "Test Corp" }
    hired.save!
    @recruit.reload
    assert_not_includes @recruit.employment_history.map { |e| e["employer"] }, "Test Corp"
  end

  # =====================
  # Validations
  # =====================

  test "validates race presence and inclusion" do
    hired = build_hired_recruit(race: nil)
    assert_not hired.valid?

    hired = build_hired_recruit(race: "invalid")
    assert_not hired.valid?

    hired = build_hired_recruit(race: "vex")
    assert hired.valid?
  end

  test "validates npc_class presence and inclusion" do
    hired = build_hired_recruit(npc_class: nil)
    assert_not hired.valid?

    hired = build_hired_recruit(npc_class: "invalid")
    assert_not hired.valid?

    hired = build_hired_recruit(npc_class: "engineer")
    assert hired.valid?
  end

  test "validates skill is between 1 and 100" do
    assert_not build_hired_recruit(skill: 0).valid?
    assert_not build_hired_recruit(skill: 101).valid?
    assert build_hired_recruit(skill: 1).valid?
    assert build_hired_recruit(skill: 100).valid?
  end

  test "validates chaos_factor is between 0 and 100" do
    assert_not build_hired_recruit(chaos_factor: -1).valid?
    assert_not build_hired_recruit(chaos_factor: 101).valid?
    assert build_hired_recruit(chaos_factor: 0).valid?
    assert build_hired_recruit(chaos_factor: 100).valid?
  end

  # =====================
  # Wage Calculation
  # =====================

  test "calculate_wage uses exponential formula" do
    low = build_hired_recruit(skill: 30, chaos_factor: 0, race: "solari")
    mid = build_hired_recruit(skill: 60, chaos_factor: 0, race: "solari")
    high = build_hired_recruit(skill: 90, chaos_factor: 0, race: "solari")

    assert low.calculate_wage < mid.calculate_wage
    assert mid.calculate_wage < high.calculate_wage
  end

  test "calculate_wage meets ROADMAP requirement: skill 90 > skill 80 * 1.5" do
    skill_80 = build_hired_recruit(skill: 80, chaos_factor: 0, race: "solari")
    skill_90 = build_hired_recruit(skill: 90, chaos_factor: 0, race: "solari")

    assert skill_90.calculate_wage > skill_80.calculate_wage * 1.5
  end

  test "calculate_wage meets ROADMAP requirement: skill 95 > skill 75 * 3" do
    skill_75 = build_hired_recruit(skill: 75, chaos_factor: 0, race: "solari")
    skill_95 = build_hired_recruit(skill: 95, chaos_factor: 0, race: "solari")

    assert skill_95.calculate_wage > skill_75.calculate_wage * 3
  end

  test "calculate_wage applies chaos discount" do
    no_chaos = build_hired_recruit(skill: 50, chaos_factor: 0, race: "solari")
    high_chaos = build_hired_recruit(skill: 50, chaos_factor: 100, race: "solari")

    assert no_chaos.calculate_wage > high_chaos.calculate_wage
  end

  test "calculate_wage applies racial modifiers" do
    vex = build_hired_recruit(skill: 50, chaos_factor: 0, race: "vex")
    solari = build_hired_recruit(skill: 50, chaos_factor: 0, race: "solari")
    myrmidon = build_hired_recruit(skill: 50, chaos_factor: 0, race: "myrmidon")

    # Vex: +15%, Myrmidon: -15%
    assert vex.calculate_wage > solari.calculate_wage
    assert solari.calculate_wage > myrmidon.calculate_wage
  end

  # =====================
  # Quirks System
  # =====================

  test "quirks returns array from stats" do
    hired = build_hired_recruit
    hired.stats = { "quirks" => [ "efficient", "lazy" ] }

    assert_equal [ "efficient", "lazy" ], hired.quirks
  end

  test "quirks returns empty array when stats nil" do
    hired = build_hired_recruit
    hired.stats = nil

    assert_equal [], hired.quirks
  end

  test "performance_modifier calculates from quirks" do
    hired = build_hired_recruit
    hired.stats = { "quirks" => [ "efficient" ] }  # +15%

    assert_in_delta 1.15, hired.performance_modifier, 0.01
  end

  test "performance_modifier compounds multiple quirks" do
    hired = build_hired_recruit
    hired.stats = { "quirks" => [ "efficient", "lazy" ] }  # +15%, -15%

    expected = 1.15 * 0.85  # ~0.9775
    assert_in_delta expected, hired.performance_modifier, 0.01
  end

  test "performance_modifier returns 1.0 for no quirks" do
    hired = build_hired_recruit
    hired.stats = { "quirks" => [] }

    assert_equal 1.0, hired.performance_modifier
  end

  # =====================
  # Associations
  # =====================

  test "has_many hirings" do
    hired = HiredRecruit.create_from_recruit!(@recruit, @user)
    ship = create_test_ship

    hiring = Hiring.create!(
      user: @user,
      hired_recruit: hired,
      assignable: ship,
      status: "active",
      wage: hired.calculate_wage,
      hired_at: Time.current
    )

    assert_includes hired.hirings, hiring
  end

  test "has_many users through hirings" do
    hired = HiredRecruit.create_from_recruit!(@recruit, @user)
    ship = create_test_ship

    Hiring.create!(
      user: @user,
      hired_recruit: hired,
      assignable: ship,
      status: "active",
      wage: hired.calculate_wage,
      hired_at: Time.current
    )

    assert_includes hired.users, @user
  end

  private

  def build_hired_recruit(overrides = {})
    defaults = {
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 20,
      stats: {},
      employment_history: []
    }
    HiredRecruit.new(defaults.merge(overrides))
  end

  def create_test_ship
    Ship.create!(
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
end
