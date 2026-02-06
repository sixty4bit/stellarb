# frozen_string_literal: true

require "test_helper"

class MarketplaceFeesTest < ActiveSupport::TestCase
  def setup
    @user = users(:pilot)
    
    # Create a fresh system with minerals for testing
    @system = System.create!(
      name: "Trade System",
      short_id: "sy-trade-#{SecureRandom.hex(4)}",
      x: 6,
      y: 6,
      z: 6,
      properties: {
        star_type: "yellow_dwarf",
        planet_count: 3,
        hazard_level: 0,
        base_prices: { "ore" => 100, "fuel" => 200 },
        mineral_distribution: {
          "0" => { "minerals" => %w[iron copper], "abundance" => "common" }
        }
      }
    )
  end

  # =========================================
  # MARKETPLACE REQUIREMENT FOR TRADING
  # =========================================

  test "system without marketplace has trading disabled" do
    # No marketplace built
    assert_not @system.trading_enabled?, "Trading should be disabled without marketplace"
  end

  test "system with marketplace has trading enabled" do
    create_marketplace(tier: 1)
    assert @system.trading_enabled?, "Trading should be enabled with marketplace"
  end

  test "disabled marketplace disables trading" do
    marketplace = create_marketplace(tier: 1)
    marketplace.update!(disabled_at: Time.current)
    
    assert_not @system.trading_enabled?, "Trading should be disabled with disabled marketplace"
  end

  test "destroyed marketplace disables trading" do
    marketplace = create_marketplace(tier: 1)
    marketplace.update!(status: "destroyed")
    
    assert_not @system.trading_enabled?, "Trading should be disabled with destroyed marketplace"
  end

  # =========================================
  # MARKETPLACE FEE BY TIER
  # =========================================

  test "tier 1 marketplace has 5% fee" do
    marketplace = create_marketplace(tier: 1)
    assert_equal 0.05, marketplace.marketplace_fee_rate
  end

  test "tier 2 marketplace has 4% fee" do
    marketplace = create_marketplace(tier: 2)
    assert_equal 0.04, marketplace.marketplace_fee_rate
  end

  test "tier 3 marketplace has 3% fee" do
    marketplace = create_marketplace(tier: 3)
    assert_equal 0.03, marketplace.marketplace_fee_rate
  end

  test "tier 4 marketplace has 2% fee" do
    marketplace = create_marketplace(tier: 4)
    assert_equal 0.02, marketplace.marketplace_fee_rate
  end

  test "tier 5 marketplace has 1% fee" do
    marketplace = create_marketplace(tier: 5)
    assert_equal 0.01, marketplace.marketplace_fee_rate
  end

  test "system marketplace_fee returns correct fee based on marketplace tier" do
    create_marketplace(tier: 3)
    assert_equal 0.03, @system.marketplace_fee_rate
  end

  test "system without marketplace returns nil marketplace fee" do
    assert_nil @system.marketplace_fee_rate
  end

  test "marketplace fee calculation on transaction" do
    marketplace = create_marketplace(tier: 1)  # 5% fee
    
    # 100 credits transaction at 5% = 5 credits fee
    assert_equal 5, marketplace.calculate_fee(100)
    
    # 1000 credits transaction at 5% = 50 credits fee
    assert_equal 50, marketplace.calculate_fee(1000)
  end

  test "higher tier marketplace takes smaller fee" do
    t1_marketplace = create_marketplace(tier: 1)
    t1_fee = t1_marketplace.calculate_fee(1000)  # 5% = 50
    
    # Clean up and create T5
    t1_marketplace.destroy!
    
    t5_marketplace = create_marketplace(tier: 5)
    t5_fee = t5_marketplace.calculate_fee(1000)  # 1% = 10
    
    assert_equal 50, t1_fee
    assert_equal 10, t5_fee
    assert t5_fee < t1_fee, "T5 fee should be less than T1 fee"
  end

  # =========================================
  # NPC VOLUME MULTIPLIER BY TIER
  # =========================================

  test "tier 1 marketplace has 1x NPC volume" do
    marketplace = create_marketplace(tier: 1)
    assert_equal 1, marketplace.npc_volume_multiplier
  end

  test "tier 2 marketplace has 7x NPC volume" do
    marketplace = create_marketplace(tier: 2)
    assert_equal 7, marketplace.npc_volume_multiplier
  end

  test "tier 3 marketplace has 13x NPC volume" do
    marketplace = create_marketplace(tier: 3)
    assert_equal 13, marketplace.npc_volume_multiplier
  end

  test "tier 4 marketplace has 19x NPC volume" do
    marketplace = create_marketplace(tier: 4)
    assert_equal 19, marketplace.npc_volume_multiplier
  end

  test "tier 5 marketplace has 25x NPC volume" do
    marketplace = create_marketplace(tier: 5)
    assert_equal 25, marketplace.npc_volume_multiplier
  end

  test "system npc_volume_multiplier returns correct multiplier based on marketplace tier" do
    create_marketplace(tier: 4)
    assert_equal 19, @system.npc_volume_multiplier
  end

  test "system without marketplace returns 0 npc volume multiplier" do
    assert_equal 0, @system.npc_volume_multiplier
  end

  # =========================================
  # NON-MARKETPLACE BUILDINGS
  # =========================================

  test "non-marketplace building returns nil for marketplace fee rate" do
    warehouse = Building.create!(
      user: @user,
      system: @system,
      name: "Warehouse",
      function: "logistics",
      race: "vex",
      tier: 3
    )
    
    assert_nil warehouse.marketplace_fee_rate
  end

  test "non-marketplace building returns nil for npc volume multiplier" do
    warehouse = Building.create!(
      user: @user,
      system: @system,
      name: "Warehouse",
      function: "logistics",
      race: "vex",
      tier: 3
    )
    
    assert_nil warehouse.npc_volume_multiplier
  end

  private

  def create_marketplace(tier:)
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market T#{tier}",
      function: "civic",
      race: "vex",
      tier: tier
    )
  end
end
