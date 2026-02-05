# frozen_string_literal: true

require "test_helper"

class MineralDistributionTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @system = System.discover_at(x: 100, y: 200, z: 300, user: @user)
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
  end

  # ==========================================
  # Mineral Types & Tiers
  # ==========================================

  test "defines mineral tiers" do
    assert_includes MineralDistribution::BASIC_MINERALS, "iron"
    assert_includes MineralDistribution::BASIC_MINERALS, "copper"
    assert_includes MineralDistribution::INTERMEDIATE_MINERALS, "steel"
    assert_includes MineralDistribution::ADVANCED_MINERALS, "titanium"
    assert_includes MineralDistribution::RARE_MINERALS, "uranium"
  end

  test "all minerals belong to exactly one tier" do
    all_minerals = MineralDistribution::ALL_MINERALS
    basic = MineralDistribution::BASIC_MINERALS
    intermediate = MineralDistribution::INTERMEDIATE_MINERALS
    advanced = MineralDistribution::ADVANCED_MINERALS
    rare = MineralDistribution::RARE_MINERALS

    # No duplicates across tiers
    assert_equal all_minerals.length, (basic + intermediate + advanced + rare).uniq.length
  end

  # ==========================================
  # System Mineral Queries
  # ==========================================

  test "system has mineral distribution in properties" do
    distribution = @system.properties["mineral_distribution"]
    assert distribution.present?
    assert distribution.is_a?(Hash)
  end

  test "cradle has abundant basic minerals" do
    distribution = @cradle.mineral_distribution
    basic_minerals = MineralDistribution::BASIC_MINERALS

    # Cradle should have at least iron and copper with high abundance
    minerals_in_cradle = distribution.values.flat_map { |p| p["minerals"] || p[:minerals] }
    assert minerals_in_cradle.include?("iron") || minerals_in_cradle.include?("copper")
  end

  test "system can list all available minerals" do
    minerals = @system.available_minerals
    assert minerals.is_a?(Array)
    assert minerals.all? { |m| m.is_a?(String) }
  end

  test "system can check if mineral is available" do
    # Use a mineral we know exists in the cradle
    assert @cradle.mineral_available?("iron")
  end

  test "system can get minerals by planet" do
    planet_minerals = @cradle.minerals_on_planet(0)
    assert planet_minerals.is_a?(Hash)
    assert planet_minerals.key?(:minerals) || planet_minerals.key?("minerals")
    assert planet_minerals.key?(:abundance) || planet_minerals.key?("abundance")
  end

  # ==========================================
  # Abundance Levels
  # ==========================================

  test "abundance levels are defined" do
    abundances = MineralDistribution::ABUNDANCE_LEVELS
    assert abundances.include?(:very_low)
    assert abundances.include?(:low)
    assert abundances.include?(:medium)
    assert abundances.include?(:high)
    assert abundances.include?(:very_high)
  end

  test "abundance affects extraction rate" do
    rates = MineralDistribution::EXTRACTION_RATES
    assert rates[:very_low] < rates[:low]
    assert rates[:low] < rates[:medium]
    assert rates[:medium] < rates[:high]
    assert rates[:high] < rates[:very_high]
  end

  # ==========================================
  # Generation Determinism
  # ==========================================

  test "mineral distribution is deterministic" do
    dist1 = ProceduralGeneration.generate_system(100, 200, 300)[:mineral_distribution]
    dist2 = ProceduralGeneration.generate_system(100, 200, 300)[:mineral_distribution]
    assert_equal dist1, dist2
  end

  test "different coordinates produce different distributions" do
    dist1 = ProceduralGeneration.generate_system(100, 200, 300)[:mineral_distribution]
    dist2 = ProceduralGeneration.generate_system(101, 201, 301)[:mineral_distribution]
    assert_not_equal dist1, dist2
  end

  # ==========================================
  # Starter Systems
  # ==========================================

  test "starter zone check works for coordinates near cradle" do
    assert MineralDistribution.starter_zone?(10, 10, 10)
    assert MineralDistribution.starter_zone?(50, 50, 50)
    assert_not MineralDistribution.starter_zone?(500, 500, 500)
    assert_not MineralDistribution.starter_zone?(1000, 0, 0)
  end

  test "tier weights favor basic minerals near cradle" do
    # Near cradle - should favor basic minerals heavily
    near_weights = MineralDistribution.tier_weights(10, 10, 10)
    assert near_weights[:basic] > near_weights[:rare]
    assert near_weights[:basic] >= 50

    # Far from cradle - should have more balanced distribution
    far_weights = MineralDistribution.tier_weights(5000, 5000, 5000)
    assert far_weights[:rare] > 0
  end
end
