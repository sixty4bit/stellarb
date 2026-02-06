# frozen_string_literal: true

require "test_helper"

class BuildingTierTablesTest < ActiveSupport::TestCase
  # ===========================================
  # Building Costs per Source Doc Section 3.3-3.6
  # Mine: 10k-250k, Warehouse: 5k-300k, Marketplace: 8k-300k, Factory: 25k-1M
  # ===========================================

  test "mine (extraction) costs match source doc" do
    expected = { 1 => 10_000, 2 => 25_000, 3 => 50_000, 4 => 100_000, 5 => 250_000 }
    expected.each do |tier, cost|
      assert_equal cost, Building::BUILDING_COSTS["extraction"][tier],
        "Mine tier #{tier} should cost #{cost}"
    end
  end

  test "warehouse (logistics) costs match source doc" do
    expected = { 1 => 5_000, 2 => 15_000, 3 => 40_000, 4 => 100_000, 5 => 300_000 }
    expected.each do |tier, cost|
      assert_equal cost, Building::BUILDING_COSTS["logistics"][tier],
        "Warehouse tier #{tier} should cost #{cost}"
    end
  end

  test "marketplace (civic) costs match source doc" do
    expected = { 1 => 8_000, 2 => 20_000, 3 => 50_000, 4 => 120_000, 5 => 300_000 }
    expected.each do |tier, cost|
      assert_equal cost, Building::BUILDING_COSTS["civic"][tier],
        "Marketplace tier #{tier} should cost #{cost}"
    end
  end

  test "factory (refining) costs match source doc" do
    expected = { 1 => 25_000, 2 => 60_000, 3 => 150_000, 4 => 400_000, 5 => 1_000_000 }
    expected.each do |tier, cost|
      assert_equal cost, Building::BUILDING_COSTS["refining"][tier],
        "Factory tier #{tier} should cost #{cost}"
    end
  end

  # ===========================================
  # Tier Table Data Structure
  # ===========================================

  test "tier_table_for returns hash with costs and effects" do
    table = Building.tier_table_for("extraction")

    assert table.is_a?(Hash)
    assert table[:name].present?
    assert table[:tiers].is_a?(Array)
    assert_equal 5, table[:tiers].size
  end

  test "mine tier table includes supply bonus and price effect" do
    table = Building.tier_table_for("extraction")

    table[:tiers].each_with_index do |tier_data, index|
      tier = index + 1
      assert_equal tier, tier_data[:tier]
      assert tier_data[:cost].is_a?(Integer)
      assert tier_data[:effects].key?(:supply_bonus)
      assert tier_data[:effects].key?(:price_effect)
    end
  end

  test "mine tier 1 effects are correct" do
    table = Building.tier_table_for("extraction")
    tier1 = table[:tiers].first

    assert_equal 10_000, tier1[:cost]
    assert_equal "+20%", tier1[:effects][:supply_bonus]
    assert_equal "-5%", tier1[:effects][:price_effect]
  end

  test "mine tier 5 effects are correct" do
    table = Building.tier_table_for("extraction")
    tier5 = table[:tiers].last

    assert_equal 250_000, tier5[:cost]
    assert_equal "+150%", tier5[:effects][:supply_bonus]
    assert_equal "-25%", tier5[:effects][:price_effect]
  end

  test "warehouse tier table includes capacity bonus and max trade size" do
    table = Building.tier_table_for("logistics")

    table[:tiers].each do |tier_data|
      assert tier_data[:effects].key?(:capacity_bonus)
      assert tier_data[:effects].key?(:max_trade_size)
    end
  end

  test "warehouse tier 1 effects are correct" do
    table = Building.tier_table_for("logistics")
    tier1 = table[:tiers].first

    assert_equal 5_000, tier1[:cost]
    assert_equal "+50%", tier1[:effects][:capacity_bonus]
    assert_equal 500, tier1[:effects][:max_trade_size]
  end

  test "warehouse tier 5 effects are correct" do
    table = Building.tier_table_for("logistics")
    tier5 = table[:tiers].last

    assert_equal 300_000, tier5[:cost]
    assert_equal "+800%", tier5[:effects][:capacity_bonus]
    assert_equal 10_000, tier5[:effects][:max_trade_size]
  end

  test "marketplace tier table includes fee and npc volume" do
    table = Building.tier_table_for("civic")

    table[:tiers].each do |tier_data|
      assert tier_data[:effects].key?(:fee)
      assert tier_data[:effects].key?(:npc_volume)
    end
  end

  test "marketplace tier 1 effects are correct" do
    table = Building.tier_table_for("civic")
    tier1 = table[:tiers].first

    assert_equal 8_000, tier1[:cost]
    assert_equal "5%", tier1[:effects][:fee]
    assert_equal "1x", tier1[:effects][:npc_volume]
  end

  test "marketplace tier 5 effects are correct" do
    table = Building.tier_table_for("civic")
    tier5 = table[:tiers].last

    assert_equal 300_000, tier5[:cost]
    assert_equal "1%", tier5[:effects][:fee]
    assert_equal "25x", tier5[:effects][:npc_volume]
  end

  test "factory tier table includes input demand and output supply" do
    table = Building.tier_table_for("refining")

    table[:tiers].each do |tier_data|
      assert tier_data[:effects].key?(:input_demand)
      assert tier_data[:effects].key?(:output_supply)
    end
  end

  test "factory tier 1 effects are correct" do
    table = Building.tier_table_for("refining")
    tier1 = table[:tiers].first

    assert_equal 25_000, tier1[:cost]
    assert_equal "+10%", tier1[:effects][:input_demand]
    assert_equal "-5%", tier1[:effects][:output_supply]
  end

  test "factory tier 5 effects are correct" do
    table = Building.tier_table_for("refining")
    tier5 = table[:tiers].last

    assert_equal 1_000_000, tier5[:cost]
    assert_equal "+30%", tier5[:effects][:input_demand]
    assert_equal "-25%", tier5[:effects][:output_supply]
  end

  # ===========================================
  # All Tier Tables
  # ===========================================

  test "all_tier_tables returns tables for all building types" do
    tables = Building.all_tier_tables

    assert tables.is_a?(Hash)
    %w[extraction logistics civic refining].each do |function|
      assert tables.key?(function), "Missing table for #{function}"
    end
  end

  # ===========================================
  # Upgrade Costs
  # ===========================================

  test "upgrade cost is difference between tiers" do
    # Tier 1 -> 2 mine: 25000 - 10000 = 15000
    building = Building.new(function: "extraction", tier: 1, race: "vex")
    assert_equal 15_000, building.upgrade_cost
  end

  test "upgrade cost for tier 4 to 5 mine" do
    building = Building.new(function: "extraction", tier: 4, race: "vex")
    # 250000 - 100000 = 150000
    assert_equal 150_000, building.upgrade_cost
  end

  test "upgrade cost returns nil at max tier" do
    building = Building.new(function: "extraction", tier: 5, race: "vex")
    assert_nil building.upgrade_cost
  end
end
