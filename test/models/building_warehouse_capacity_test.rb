# frozen_string_literal: true

require "test_helper"

class BuildingWarehouseCapacityTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @system = systems(:cradle)
  end

  # ===========================================
  # Warehouse Capacity Bonus (affects market capacity)
  # ===========================================

  test "warehouse_capacity_bonus returns 0.5 for tier 1 (50%)" do
    warehouse = create_warehouse(tier: 1)
    assert_equal 0.5, warehouse.warehouse_capacity_bonus
  end

  test "warehouse_capacity_bonus returns 1.0 for tier 2 (100%)" do
    warehouse = create_warehouse(tier: 2)
    assert_equal 1.0, warehouse.warehouse_capacity_bonus
  end

  test "warehouse_capacity_bonus returns 2.0 for tier 3 (200%)" do
    warehouse = create_warehouse(tier: 3)
    assert_equal 2.0, warehouse.warehouse_capacity_bonus
  end

  test "warehouse_capacity_bonus returns 4.0 for tier 4 (400%)" do
    warehouse = create_warehouse(tier: 4)
    assert_equal 4.0, warehouse.warehouse_capacity_bonus
  end

  test "warehouse_capacity_bonus returns 8.0 for tier 5 (800%)" do
    warehouse = create_warehouse(tier: 5)
    assert_equal 8.0, warehouse.warehouse_capacity_bonus
  end

  test "warehouse_capacity_bonus returns 0 for non-logistics buildings" do
    extraction = create_building(function: "extraction", tier: 3)
    assert_equal 0, extraction.warehouse_capacity_bonus
  end

  # ===========================================
  # Warehouse Max Trade Size
  # ===========================================

  test "warehouse_max_trade_size returns 500 for tier 1" do
    warehouse = create_warehouse(tier: 1)
    assert_equal 500, warehouse.warehouse_max_trade_size
  end

  test "warehouse_max_trade_size returns 1000 for tier 2" do
    warehouse = create_warehouse(tier: 2)
    assert_equal 1000, warehouse.warehouse_max_trade_size
  end

  test "warehouse_max_trade_size returns 2500 for tier 3" do
    warehouse = create_warehouse(tier: 3)
    assert_equal 2500, warehouse.warehouse_max_trade_size
  end

  test "warehouse_max_trade_size returns 5000 for tier 4" do
    warehouse = create_warehouse(tier: 4)
    assert_equal 5000, warehouse.warehouse_max_trade_size
  end

  test "warehouse_max_trade_size returns 10000 for tier 5" do
    warehouse = create_warehouse(tier: 5)
    assert_equal 10_000, warehouse.warehouse_max_trade_size
  end

  test "warehouse_max_trade_size returns nil for non-logistics buildings" do
    extraction = create_building(function: "extraction", tier: 3)
    assert_nil extraction.warehouse_max_trade_size
  end

  # ===========================================
  # Warehouse Restock Rate Multiplier
  # ===========================================

  test "warehouse_restock_multiplier returns 1.25 for tier 1 (25% boost)" do
    warehouse = create_warehouse(tier: 1)
    assert_equal 1.25, warehouse.warehouse_restock_multiplier
  end

  test "warehouse_restock_multiplier returns 1.5 for tier 2 (50% boost)" do
    warehouse = create_warehouse(tier: 2)
    assert_equal 1.5, warehouse.warehouse_restock_multiplier
  end

  test "warehouse_restock_multiplier returns 2.0 for tier 3 (100% boost)" do
    warehouse = create_warehouse(tier: 3)
    assert_equal 2.0, warehouse.warehouse_restock_multiplier
  end

  test "warehouse_restock_multiplier returns 3.0 for tier 4 (200% boost)" do
    warehouse = create_warehouse(tier: 4)
    assert_equal 3.0, warehouse.warehouse_restock_multiplier
  end

  test "warehouse_restock_multiplier returns 5.0 for tier 5 (400% boost)" do
    warehouse = create_warehouse(tier: 5)
    assert_equal 5.0, warehouse.warehouse_restock_multiplier
  end

  test "warehouse_restock_multiplier returns 1.0 for non-logistics buildings" do
    extraction = create_building(function: "extraction", tier: 3)
    assert_equal 1.0, extraction.warehouse_restock_multiplier
  end

  # ===========================================
  # Warehouse Check
  # ===========================================

  test "warehouse? returns true for logistics function buildings" do
    warehouse = create_warehouse(tier: 1)
    assert warehouse.warehouse?
  end

  test "warehouse? returns false for non-logistics buildings" do
    extraction = create_building(function: "extraction", tier: 3)
    refute extraction.warehouse?
  end

  # ===========================================
  # Disabled Warehouse
  # ===========================================

  test "warehouse_capacity_bonus returns 0 when warehouse is disabled" do
    warehouse = create_warehouse(tier: 5)
    warehouse.update!(disabled_at: Time.current)
    assert_equal 0, warehouse.warehouse_capacity_bonus
  end

  test "warehouse_max_trade_size returns nil when warehouse is disabled" do
    warehouse = create_warehouse(tier: 5)
    warehouse.update!(disabled_at: Time.current)
    assert_nil warehouse.warehouse_max_trade_size
  end

  test "warehouse_restock_multiplier returns 1.0 when warehouse is disabled" do
    warehouse = create_warehouse(tier: 5)
    warehouse.update!(disabled_at: Time.current)
    assert_equal 1.0, warehouse.warehouse_restock_multiplier
  end

  private

  def create_warehouse(tier:)
    create_building(function: "logistics", tier: tier)
  end

  def create_building(function:, tier:)
    Building.create!(
      user: @user,
      system: @system,
      name: "Test #{function.titleize} T#{tier}",
      race: "vex",
      function: function,
      tier: tier,
      status: "active",
      building_attributes: {}
    )
  end
end
