require "test_helper"

class WageCalculationTest < ActiveSupport::TestCase
  # According to the ROADMAP Section 4.4.3:
  # "The Wage Spiral: Higher skill NPCs demand exponentially higher wages"
  # Target metric: skill_90_wage > skill_80_wage * 1.5

  test "wage calculation exists on HiredRecruit" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 25
    )

    assert_respond_to recruit, :calculate_wage
  end

  test "base wage calculation scales with skill" do
    low_skill = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 20, chaos_factor: 25)
    mid_skill = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 50, chaos_factor: 25)
    high_skill = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 80, chaos_factor: 25)

    low_wage = low_skill.calculate_wage
    mid_wage = mid_skill.calculate_wage
    high_wage = high_skill.calculate_wage

    assert low_wage < mid_wage, "Mid skill (#{mid_wage}) should earn more than low skill (#{low_wage})"
    assert mid_wage < high_wage, "High skill (#{high_wage}) should earn more than mid skill (#{mid_wage})"
  end

  test "wage scaling is exponential not linear" do
    # If linear: skill 80 would earn 4x skill 20
    # If exponential: skill 80 should earn much more than 4x skill 20
    skill_20 = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 20, chaos_factor: 25)
    skill_80 = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 80, chaos_factor: 25)

    wage_20 = skill_20.calculate_wage
    wage_80 = skill_80.calculate_wage

    # Exponential should result in much more than 4x (linear would be 80/20 = 4)
    # With exponential formula wage = base * (growth_factor ** skill), ratio should be >> 4
    ratio = wage_80.to_f / wage_20

    assert ratio > 6, "Exponential scaling should result in ratio > 6, got #{ratio}"
  end

  test "ROADMAP criteria: skill 90 wage is more than 1.5x skill 80 wage" do
    skill_80 = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 80, chaos_factor: 25)
    skill_90 = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 90, chaos_factor: 25)

    wage_80 = skill_80.calculate_wage
    wage_90 = skill_90.calculate_wage

    assert wage_90 > wage_80 * 1.5,
      "Skill 90 wage (#{wage_90}) should be > 1.5x skill 80 wage (#{wage_80 * 1.5})"
  end

  test "legendary tier (skill 95+) wages are dramatically higher" do
    skill_75 = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 75, chaos_factor: 25)
    skill_95 = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 95, chaos_factor: 25)

    wage_75 = skill_75.calculate_wage
    wage_95 = skill_95.calculate_wage

    # Legendary should cost at least 3x rare tier
    assert wage_95 > wage_75 * 3,
      "Legendary wage (#{wage_95}) should be > 3x rare wage (#{wage_75 * 3})"
  end

  test "chaos factor provides discount for risky hires" do
    stable_hire = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 70, chaos_factor: 10)
    risky_hire = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 70, chaos_factor: 80)

    stable_wage = stable_hire.calculate_wage
    risky_wage = risky_hire.calculate_wage

    assert risky_wage < stable_wage,
      "Risky hire (chaos=80, wage=#{risky_wage}) should cost less than stable (chaos=10, wage=#{stable_wage})"
  end

  test "chaos factor discount is meaningful but not extreme" do
    stable_hire = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 70, chaos_factor: 0)
    max_chaos = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 70, chaos_factor: 100)

    stable_wage = stable_hire.calculate_wage
    chaos_wage = max_chaos.calculate_wage

    # Max chaos should give significant discount (20-50%) but not make them free
    discount_percent = ((stable_wage - chaos_wage).to_f / stable_wage) * 100

    assert discount_percent > 15, "Max chaos should give > 15% discount, got #{discount_percent.round(1)}%"
    assert discount_percent < 60, "Max chaos shouldn't give > 60% discount, got #{discount_percent.round(1)}%"
  end

  test "class method exponential_wage exists" do
    assert_respond_to HiredRecruit, :exponential_wage
  end

  test "exponential_wage class method calculates correctly" do
    wage = HiredRecruit.exponential_wage(skill: 50, chaos_factor: 25)

    assert wage.is_a?(Numeric), "exponential_wage should return a number"
    assert wage > 0, "exponential_wage should be positive"
  end

  test "wage calculation handles edge cases" do
    # Minimum skill
    min_skill = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 1, chaos_factor: 50)
    assert min_skill.calculate_wage > 0, "Minimum skill should still have positive wage"

    # Maximum skill
    max_skill = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 100, chaos_factor: 50)
    assert max_skill.calculate_wage > 0, "Maximum skill should have positive wage"
    assert max_skill.calculate_wage < 1_000_000, "Maximum skill wage should be reasonable (< 1M)"
  end

  test "racial bonuses affect wages for Vex" do
    # Per ROADMAP: Vex NPCs have trait "Greedy" (Higher Salary)
    vex = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 60, chaos_factor: 25)
    solari = HiredRecruit.new(race: "solari", npc_class: "engineer", skill: 60, chaos_factor: 25)

    vex_wage = vex.calculate_wage
    solari_wage = solari.calculate_wage

    assert vex_wage > solari_wage, "Vex should demand higher wages due to 'Greedy' trait"
  end
end
