require "test_helper"

class EmploymentHistoryTest < ActiveSupport::TestCase
  # According to the ROADMAP Section 5.1.6:
  # Every NPC comes with procedurally generated work history
  # 2-5 prior employment records
  # Record structure: [Employer Name] — [Duration] — [Outcome]
  # Outcome weighted by Chaos Factor

  test "HiredRecruit has employment_history jsonb" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 25,
      stats: {},
      employment_history: []
    )

    assert_respond_to recruit, :employment_history
    assert recruit.employment_history.is_a?(Array)
  end

  test "can generate employment history for new recruit" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 25,
      stats: {}
    )

    assert_respond_to recruit, :generate_employment_history!
  end

  test "employment history generates 2-5 records" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: {}
    )

    # Run multiple times to check range
    record_counts = 20.times.map do
      recruit.generate_employment_history!
      recruit.employment_history.length
    end

    assert record_counts.all? { |c| c >= 2 && c <= 5 },
      "Employment history should have 2-5 records, got: #{record_counts.uniq}"
  end

  test "each employment record has required fields" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: {}
    )

    recruit.generate_employment_history!

    recruit.employment_history.each do |record|
      assert record.key?("employer"), "Record missing employer"
      assert record.key?("duration_months"), "Record missing duration_months"
      assert record.key?("outcome"), "Record missing outcome"
    end
  end

  test "low chaos factor produces mostly clean exit outcomes" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 10,
      stats: {}
    )

    all_outcomes = 30.times.flat_map do
      recruit.generate_employment_history!
      recruit.employment_history.map { |r| r["outcome"] }
    end

    clean_exits = all_outcomes.count { |o| HiredRecruit::CLEAN_EXIT_OUTCOMES.include?(o) }
    catastrophes = all_outcomes.count { |o| HiredRecruit::CATASTROPHE_OUTCOMES.include?(o) }

    # With low chaos (0-20): 90% clean, 10% incident, 0% catastrophe
    assert clean_exits > catastrophes * 5,
      "Low chaos should produce mostly clean exits. Clean: #{clean_exits}, Catastrophes: #{catastrophes}"
  end

  test "high chaos factor produces more incidents and catastrophes" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 90,
      stats: {}
    )

    all_outcomes = 30.times.flat_map do
      recruit.generate_employment_history!
      recruit.employment_history.map { |r| r["outcome"] }
    end

    clean_exits = all_outcomes.count { |o| HiredRecruit::CLEAN_EXIT_OUTCOMES.include?(o) }
    incidents = all_outcomes.count { |o| HiredRecruit::INCIDENT_OUTCOMES.include?(o) }
    catastrophes = all_outcomes.count { |o| HiredRecruit::CATASTROPHE_OUTCOMES.include?(o) }

    # With high chaos (81-100): 10% clean, 50% incident, 40% catastrophe
    assert incidents + catastrophes > clean_exits,
      "High chaos should produce more incidents/catastrophes. Clean: #{clean_exits}, Incidents: #{incidents}, Catastrophes: #{catastrophes}"
  end

  test "employment history can include gaps" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 85,  # High chaos = more likely to have gaps
      stats: {}
    )

    # Run multiple times to check if gaps appear
    all_employers = 50.times.flat_map do
      recruit.generate_employment_history!
      recruit.employment_history.map { |r| r["employer"] }
    end

    has_gaps = all_employers.any? { |e| e == "Unlisted (gap)" || e.include?("gap") }
    assert has_gaps, "High chaos should sometimes produce employment gaps"
  end

  test "duration is in reasonable range (1-36 months)" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: {}
    )

    all_durations = 20.times.flat_map do
      recruit.generate_employment_history!
      recruit.employment_history.map { |r| r["duration_months"] }
    end

    assert all_durations.all? { |d| d >= 1 && d <= 36 },
      "Durations should be 1-36 months, got: #{all_durations.minmax}"
  end

  test "high chaos produces shorter average tenures" do
    low_chaos = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 50, chaos_factor: 10, stats: {})
    high_chaos = HiredRecruit.new(race: "vex", npc_class: "engineer", skill: 50, chaos_factor: 90, stats: {})

    low_durations = 30.times.flat_map do
      low_chaos.generate_employment_history!
      low_chaos.employment_history.map { |r| r["duration_months"] }
    end

    high_durations = 30.times.flat_map do
      high_chaos.generate_employment_history!
      high_chaos.employment_history.map { |r| r["duration_months"] }
    end

    low_avg = low_durations.sum.to_f / low_durations.length
    high_avg = high_durations.sum.to_f / high_durations.length

    assert low_avg > high_avg,
      "Low chaos should have longer average tenure (#{low_avg.round(1)}) than high chaos (#{high_avg.round(1)})"
  end

  test "add_employment_record appends to history" do
    recruit = HiredRecruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: {},
      employment_history: []
    )

    recruit.add_employment_record(
      employer: "Stellar Mining Corp",
      duration_months: 12,
      outcome: "Contract completed"
    )

    assert_equal 1, recruit.employment_history.length
    assert_equal "Stellar Mining Corp", recruit.employment_history.last["employer"]
    assert_equal 12, recruit.employment_history.last["duration_months"]
    assert_equal "Contract completed", recruit.employment_history.last["outcome"]
  end

  test "can display formatted resume" do
    recruit = HiredRecruit.new(
      race: "solari",
      npc_class: "engineer",
      skill: 72,
      chaos_factor: 15,
      stats: {},
      employment_history: [
        { "employer" => "Stellaris Corp", "duration_months" => 14, "outcome" => "Contract completed" },
        { "employer" => "Frontier Mining Co", "duration_months" => 8, "outcome" => "Promoted to Lead" }
      ]
    )

    assert_respond_to recruit, :formatted_resume
    resume = recruit.formatted_resume

    assert resume.include?("Stellaris Corp")
    assert resume.include?("14 months")
    assert resume.include?("Contract completed")
  end

  test "OUTCOME constants are defined" do
    assert defined?(HiredRecruit::CLEAN_EXIT_OUTCOMES)
    assert defined?(HiredRecruit::INCIDENT_OUTCOMES)
    assert defined?(HiredRecruit::CATASTROPHE_OUTCOMES)

    assert HiredRecruit::CLEAN_EXIT_OUTCOMES.length >= 3
    assert HiredRecruit::INCIDENT_OUTCOMES.length >= 5
    assert HiredRecruit::CATASTROPHE_OUTCOMES.length >= 3
  end

  test "EMPLOYER_NAMES constant provides names for generation" do
    assert defined?(HiredRecruit::EMPLOYER_NAMES)
    assert HiredRecruit::EMPLOYER_NAMES.length >= 10
  end
end
