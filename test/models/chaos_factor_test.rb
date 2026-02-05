require "test_helper"

class ChaosFactorTest < ActiveSupport::TestCase
  # According to the ROADMAP Section 5.1.5:
  # Chaos Factor (0-100) determines quirk count and severity
  # Higher Chaos = more disruptive quirks

  # Quirk pools
  # POSITIVE_QUIRKS = %w[meticulous efficient loyal frugal lucky]
  # NEUTRAL_QUIRKS = %w[superstitious nocturnal chatty loner gambler]
  # NEGATIVE_QUIRKS = %w[lazy greedy volatile reckless paranoid saboteur]

  test "HiredRecruit has quirks accessor" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 25,
      stats: {}
    )

    assert_respond_to recruit, :quirks
  end

  test "HiredRecruit can generate quirks based on chaos factor" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: {}
    )

    assert_respond_to recruit, :generate_quirks!
  end

  test "low chaos factor (0-20) generates 0-1 quirks" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 10,
      stats: {}
    )

    # Run multiple times to check range
    quirk_counts = 20.times.map do
      recruit.generate_quirks!
      recruit.quirks&.length || 0
    end

    assert quirk_counts.all? { |c| c <= 1 }, "Low chaos should generate 0-1 quirks, got: #{quirk_counts.uniq}"
  end

  test "medium chaos factor (21-50) generates 1-2 quirks" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 35,
      stats: {}
    )

    quirk_counts = 20.times.map do
      recruit.generate_quirks!
      recruit.quirks&.length || 0
    end

    assert quirk_counts.all? { |c| c >= 1 && c <= 2 }, "Medium chaos should generate 1-2 quirks, got: #{quirk_counts.uniq}"
  end

  test "high chaos factor (51-80) generates 1-2 quirks" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 65,
      stats: {}
    )

    quirk_counts = 20.times.map do
      recruit.generate_quirks!
      recruit.quirks&.length || 0
    end

    assert quirk_counts.all? { |c| c >= 1 && c <= 2 }, "High chaos should generate 1-2 quirks, got: #{quirk_counts.uniq}"
  end

  test "extreme chaos factor (81-100) generates 2-3 quirks" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 95,
      stats: {}
    )

    quirk_counts = 20.times.map do
      recruit.generate_quirks!
      recruit.quirks&.length || 0
    end

    assert quirk_counts.all? { |c| c >= 2 && c <= 3 }, "Extreme chaos should generate 2-3 quirks, got: #{quirk_counts.uniq}"
  end

  test "low chaos factor produces mostly positive quirks" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 10,
      stats: {}
    )

    # Run many times to get statistical distribution
    all_quirks = 50.times.flat_map do
      recruit.generate_quirks!
      recruit.quirks || []
    end

    positive_count = all_quirks.count { |q| HiredRecruit::POSITIVE_QUIRKS.include?(q) }
    negative_count = all_quirks.count { |q| HiredRecruit::NEGATIVE_QUIRKS.include?(q) }

    # With low chaos, positive should heavily outweigh negative
    assert positive_count > negative_count * 2 || all_quirks.empty?,
      "Low chaos should favor positive quirks. Positive: #{positive_count}, Negative: #{negative_count}"
  end

  test "high chaos factor produces mostly negative quirks" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 90,
      stats: {}
    )

    all_quirks = 50.times.flat_map do
      recruit.generate_quirks!
      recruit.quirks || []
    end

    positive_count = all_quirks.count { |q| HiredRecruit::POSITIVE_QUIRKS.include?(q) }
    negative_count = all_quirks.count { |q| HiredRecruit::NEGATIVE_QUIRKS.include?(q) }

    assert negative_count > positive_count * 2,
      "High chaos should favor negative quirks. Positive: #{positive_count}, Negative: #{negative_count}"
  end

  test "quirks affect performance calculation" do
    efficient_recruit = HiredRecruit.new(
      race: "solari",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 10,
      stats: { quirks: ["efficient"] }
    )

    lazy_recruit = HiredRecruit.new(
      race: "solari",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 10,
      stats: { quirks: ["lazy"] }
    )

    assert_respond_to efficient_recruit, :performance_modifier

    efficient_mod = efficient_recruit.performance_modifier
    lazy_mod = lazy_recruit.performance_modifier

    assert efficient_mod > lazy_mod,
      "Efficient quirk (#{efficient_mod}) should give better performance than lazy (#{lazy_mod})"
  end

  test "quirks stored in stats jsonb" do
    recruit = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: {}
    )

    recruit.generate_quirks!

    assert recruit.stats.key?("quirks"), "Quirks should be stored in stats jsonb"
    assert recruit.stats["quirks"].is_a?(Array), "Quirks should be an array"
  end

  test "multiple quirks stack their effects" do
    # NPC with two negative quirks
    double_negative = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: { "quirks" => ["lazy", "reckless"] }
    )

    # NPC with one negative quirk
    single_negative = HiredRecruit.new(
      race: "vex",
      npc_class: "engineer",
      skill: 50,
      chaos_factor: 50,
      stats: { "quirks" => ["lazy"] }
    )

    double_mod = double_negative.performance_modifier
    single_mod = single_negative.performance_modifier

    assert double_mod < single_mod,
      "Two negative quirks (#{double_mod}) should be worse than one (#{single_mod})"
  end

  test "QUIRK constants are defined" do
    assert defined?(HiredRecruit::POSITIVE_QUIRKS)
    assert defined?(HiredRecruit::NEUTRAL_QUIRKS)
    assert defined?(HiredRecruit::NEGATIVE_QUIRKS)

    assert HiredRecruit::POSITIVE_QUIRKS.length >= 5
    assert HiredRecruit::NEUTRAL_QUIRKS.length >= 5
    assert HiredRecruit::NEGATIVE_QUIRKS.length >= 5
  end

  test "QUIRK_EFFECTS provides modifiers for each quirk" do
    assert defined?(HiredRecruit::QUIRK_EFFECTS)

    all_quirks = HiredRecruit::POSITIVE_QUIRKS +
                 HiredRecruit::NEUTRAL_QUIRKS +
                 HiredRecruit::NEGATIVE_QUIRKS

    all_quirks.each do |quirk|
      assert HiredRecruit::QUIRK_EFFECTS.key?(quirk),
        "Missing effect definition for quirk: #{quirk}"
    end
  end
end
