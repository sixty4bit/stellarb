# frozen_string_literal: true

require "test_helper"

class CatastropheGeneratorTest < ActiveSupport::TestCase
  # === Pip Event Message Generation ===

  test "generates unique pip infestation descriptions" do
    descriptions = 100.times.map { CatastropheGenerator.generate_pip_description }

    # Should have high variety
    unique_count = descriptions.uniq.count
    assert unique_count >= 80, "Expected at least 80 unique descriptions, got #{unique_count}"
  end

  test "pip description follows formula: [Critical_System] disabled because Pips [Absurd_Action] resulting in [Ridiculous_Consequence]" do
    description = CatastropheGenerator.generate_pip_description

    # Should contain system, action, and consequence
    assert description.present?
    assert description.length > 50, "Description should be elaborate (got: #{description.length} chars)"

    # Check it's not generic
    refute_equal "Pip infestation", description
    refute_equal "System disabled", description
  end

  test "generates at least 100 unique pip message combinations" do
    seen = Set.new
    attempts = 0
    max_attempts = 500

    while seen.size < 100 && attempts < max_attempts
      seen << CatastropheGenerator.generate_pip_description
      attempts += 1
    end

    assert seen.size >= 100,
      "Expected at least 100 unique combinations but only got #{seen.size} after #{attempts} attempts"
  end

  # === Examples from ROADMAP ===

  test "can generate weapon failure style descriptions" do
    description = CatastropheGenerator.generate_pip_description(system_type: :weapon)

    # Should reference weapon system
    weapon_terms = [ "Laser", "Battery", "Turret", "Cannon", "Weapon", "Beam", "Gun", "Plasma", "Launcher" ]
    assert weapon_terms.any? { |term| description.include?(term) },
      "Weapon description should reference weapon systems: #{description}"
  end

  test "can generate cargo failure style descriptions" do
    description = CatastropheGenerator.generate_pip_description(system_type: :cargo)

    cargo_terms = [ "Cargo", "Bay", "Hold", "Storage", "Container", "Jettison" ]
    assert cargo_terms.any? { |term| description.include?(term) },
      "Cargo description should reference cargo systems: #{description}"
  end

  test "can generate navigation failure style descriptions" do
    description = CatastropheGenerator.generate_pip_description(system_type: :navigation)

    nav_terms = [ "Nav", "Autopilot", "Navigation", "Computer", "Course", "Heading" ]
    assert nav_terms.any? { |term| description.include?(term) },
      "Navigation description should reference nav systems: #{description}"
  end

  # === Regular (Non-Pip) Incidents ===

  test "generates severity-appropriate descriptions for T1 minor glitch" do
    description = CatastropheGenerator.generate_description(severity: 1)

    # T1 should be minor, mundane
    assert description.present?
    # Expanded list to cover all T1 flavors
    minor_terms = [ "misalignment", "vending", "coffee", "drama", "minor", "glitch", "calibration",
                   "sneeze", "dust", "light", "sentience", "turbulence", "check engine" ]
    assert minor_terms.any? { |term| description.downcase.include?(term.downcase) },
      "T1 description should be mundane: #{description}"
  end

  test "generates severity-appropriate descriptions for T5 catastrophe" do
    description = CatastropheGenerator.generate_description(severity: 5)

    # T5 should be dramatic
    assert description.present?
    dramatic_terms = [ "explosion", "meltdown", "catastroph", "critical", "total", "mutiny", "breach" ]
    assert dramatic_terms.any? { |term| description.downcase.include?(term.downcase) },
      "T5 description should be dramatic: #{description}"
  end

  # === Racial Voice (NPC Personality) ===

  test "generates Vex-style incident reports (greedy, emotional about money)" do
    report = CatastropheGenerator.generate_incident_report(
      severity: 3,
      race: "vex",
      npc_name: "Broker Sly"
    )

    # Vex should mention money/profit/cost
    money_terms = [ "$", "credit", "cost", "profit", "expense", "budget", "pay", "money" ]
    assert money_terms.any? { |term| report.downcase.include?(term.downcase) },
      "Vex report should mention money: #{report}"
  end

  test "generates Solari-style incident reports (precise, probability-based)" do
    report = CatastropheGenerator.generate_incident_report(
      severity: 3,
      race: "solari",
      npc_name: "7-Alpha-Null"
    )

    # Solari should be precise with numbers/probability
    precise_terms = [ "%", "probability", "calculated", "efficiency", "analysis", "data" ]
    assert precise_terms.any? { |term| report.downcase.include?(term.downcase) },
      "Solari report should be precise: #{report}"
  end

  test "generates Krog-style incident reports (blunt, aggressive)" do
    report = CatastropheGenerator.generate_incident_report(
      severity: 3,
      race: "krog",
      npc_name: "Foreman Zorg"
    )

    # Krog should be aggressive/blunt
    aggressive_terms = [ "!", "smash", "crush", "destroy", "fight", "broken", "bleeding", "armor" ]
    assert aggressive_terms.any? { |term| report.downcase.include?(term.downcase) },
      "Krog report should be aggressive: #{report}"
  end

  test "generates Myrmidon-style incident reports (collective, cryptic)" do
    report = CatastropheGenerator.generate_incident_report(
      severity: 3,
      race: "myrmidon",
      npc_name: "Cluster 447"
    )

    # Myrmidon should use collective language
    collective_terms = [ "we", "the hive", "collective", "unit", "drone", "swarm", "consensus" ]
    assert collective_terms.any? { |term| report.downcase.include?(term.downcase) },
      "Myrmidon report should be collective: #{report}"
  end

  # === The "Mad Libs" Complaint System ===

  test "mad libs generator produces varied outputs" do
    complaints = 50.times.map { CatastropheGenerator.generate_mad_libs_complaint }

    unique_count = complaints.uniq.count
    assert unique_count >= 40, "Mad libs should produce variety (got #{unique_count} unique from 50)"
  end

  test "mad libs follows structure: [NPC_Name] is [Negative_State] because [Mundane_Object] is [SciFi_Problem]" do
    # Generate with fixed NPC name to verify structure
    complaint = CatastropheGenerator.generate_mad_libs_complaint(npc_name: "Test NPC")

    assert_includes complaint, "Test NPC"

    # Should have "is ... because" structure
    assert_match(/Test NPC is .+ because the .+ is .+\./, complaint,
      "Should follow mad libs structure: #{complaint}")
  end

  # === Repair Cost Estimation ===

  test "estimates repair cost based on severity tier" do
    t1_cost = CatastropheGenerator.estimate_repair_cost(severity: 1, asset_value: 10000)
    t5_cost = CatastropheGenerator.estimate_repair_cost(severity: 5, asset_value: 10000)

    # T1 should be negligible, T5 should be 80% of asset value
    assert t1_cost < 500, "T1 should be cheap: #{t1_cost}"
    assert t5_cost >= 7000, "T5 should be nearly replacement cost: #{t5_cost}"
    assert t5_cost > t1_cost * 10, "T5 should be much more expensive than T1"
  end

  test "pip infestation purge yields pip fur" do
    rewards = CatastropheGenerator.purge_rewards

    assert rewards[:pip_fur].present?
    assert rewards[:pip_fur] > 0
  end
end
