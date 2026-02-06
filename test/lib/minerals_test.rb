# frozen_string_literal: true

require "test_helper"

class MineralsTest < ActiveSupport::TestCase
  test "defines exactly 60 minerals" do
    assert_equal 60, Minerals::ALL.size
  end

  test "defines 50 real minerals across 4 tiers" do
    real_minerals = Minerals::ALL.reject { |m| m[:tier] == :futuristic }
    assert_equal 50, real_minerals.size

    tier_counts = real_minerals.group_by { |m| m[:tier] }.transform_values(&:size)
    assert_equal 10, tier_counts[:common], "Expected 10 Tier 1 (common) minerals"
    assert_equal 15, tier_counts[:uncommon], "Expected 15 Tier 2 (uncommon) minerals"
    assert_equal 15, tier_counts[:rare], "Expected 15 Tier 3 (rare) minerals"
    assert_equal 10, tier_counts[:exotic], "Expected 10 Tier 4 (exotic) minerals"
  end

  test "defines 10 futuristic minerals with system-type mappings" do
    futuristic = Minerals::ALL.select { |m| m[:tier] == :futuristic }
    assert_equal 10, futuristic.size

    futuristic.each do |mineral|
      assert mineral[:found_in].present?, "#{mineral[:name]} should have found_in mapping"
    end
  end

  test "each mineral has required attributes" do
    Minerals::ALL.each do |mineral|
      assert mineral[:name].present?, "Mineral missing name"
      assert mineral[:category].present?, "#{mineral[:name]} missing category"
      assert mineral[:base_price].is_a?(Numeric), "#{mineral[:name]} missing base_price"
      assert mineral[:tier].present?, "#{mineral[:name]} missing tier"
    end
  end

  test "lookup by name returns correct mineral" do
    iron = Minerals.find("iron")
    assert_not_nil iron
    assert_equal "Iron", iron[:name]
    assert_equal 10, iron[:base_price]
    assert_equal :common, iron[:tier]
  end

  test "lookup by name is case insensitive" do
    assert_equal Minerals.find("IRON"), Minerals.find("iron")
    assert_equal Minerals.find("Iron"), Minerals.find("IRON")
  end

  test "lookup by tier returns correct minerals" do
    common = Minerals.by_tier(:common)
    assert_equal 10, common.size
    common.each { |m| assert_equal :common, m[:tier] }

    exotic = Minerals.by_tier(:exotic)
    assert_equal 10, exotic.size
    exotic.each { |m| assert_equal :exotic, m[:tier] }
  end

  test "futuristic minerals have specific system type requirements" do
    stellarium = Minerals.find("Stellarium")
    assert_equal "Neutron Stars", stellarium[:found_in]

    voidite = Minerals.find("Voidite")
    assert_equal "Black Hole Proximity", voidite[:found_in]
  end

  test "base prices match source document" do
    # Spot check some prices from each tier
    assert_equal 10, Minerals.find("Iron")[:base_price]
    assert_equal 8, Minerals.find("Carbon")[:base_price]
    assert_equal 45, Minerals.find("Cobalt")[:base_price]
    assert_equal 100, Minerals.find("Gold")[:base_price]
    assert_equal 400, Minerals.find("Plutonium")[:base_price]
    assert_equal 500, Minerals.find("Stellarium")[:base_price]
    assert_equal 1000, Minerals.find("Exotite")[:base_price]
  end

  test "minerals have notes" do
    iron = Minerals.find("Iron")
    assert iron[:notes].present?
    assert_includes iron[:notes].downcase, "construction"
  end
end
