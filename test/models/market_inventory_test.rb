# frozen_string_literal: true

require "test_helper"

class MarketInventoryTest < ActiveSupport::TestCase
  setup do
    @system = System.cradle
    @inventory = MarketInventory.create!(
      system: @system,
      commodity: "iron",
      quantity: 100,
      max_quantity: 500,
      restock_rate: 10
    )
  end

  # ===========================================
  # Validations
  # ===========================================

  test "validates presence of commodity" do
    inventory = MarketInventory.new(system: @system, quantity: 100, max_quantity: 500)
    assert_not inventory.valid?
    assert inventory.errors[:commodity].present?
  end

  test "validates uniqueness of commodity per system" do
    duplicate = MarketInventory.new(
      system: @system,
      commodity: "iron",
      quantity: 50,
      max_quantity: 200,
      restock_rate: 5
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:commodity].present?
  end

  test "validates quantity is non-negative" do
    @inventory.quantity = -1
    assert_not @inventory.valid?
    assert @inventory.errors[:quantity].present?
  end

  test "validates max_quantity is positive" do
    @inventory.max_quantity = 0
    assert_not @inventory.valid?
    assert @inventory.errors[:max_quantity].present?
  end

  # ===========================================
  # Stock Management
  # ===========================================

  test "available? returns true when stock is sufficient" do
    assert @inventory.available?(50)
    assert @inventory.available?(100)
  end

  test "available? returns false when stock is insufficient" do
    assert_not @inventory.available?(101)
    assert_not @inventory.available?(1000)
  end

  test "decrease_stock! reduces quantity" do
    assert @inventory.decrease_stock!(30)
    assert_equal 70, @inventory.quantity
  end

  test "decrease_stock! returns false if insufficient stock" do
    assert_not @inventory.decrease_stock!(150)
    assert_equal 100, @inventory.quantity
  end

  test "increase_stock! adds to quantity" do
    @inventory.increase_stock!(50)
    assert_equal 150, @inventory.quantity
  end

  test "increase_stock! caps at max_quantity" do
    @inventory.increase_stock!(1000)
    assert_equal 500, @inventory.quantity
  end

  test "increase_stock! returns actual amount added" do
    # 100 current, 500 max, so only 400 can be added
    actual = @inventory.increase_stock!(1000)
    assert_equal 400, actual
  end

  test "restock! adds restock_rate amount" do
    @inventory.update!(quantity: 90)
    @inventory.restock!
    assert_equal 100, @inventory.quantity
  end

  test "restock! caps at max_quantity" do
    @inventory.update!(quantity: 495)
    @inventory.restock!
    assert_equal 500, @inventory.quantity
  end

  # ===========================================
  # Procedural Generation
  # ===========================================

  test "generate_for_system creates inventory for all commodities" do
    # The Cradle has iron, copper, water, food, fuel, luxury_goods
    inventories = MarketInventory.generate_for_system(@system)
    
    assert_equal 6, inventories.count
    assert inventories.any? { |i| i.commodity == "iron" }
    assert inventories.any? { |i| i.commodity == "copper" }
    assert inventories.any? { |i| i.commodity == "water" }
    assert inventories.any? { |i| i.commodity == "food" }
    assert inventories.any? { |i| i.commodity == "fuel" }
    assert inventories.any? { |i| i.commodity == "luxury_goods" }
  end

  test "generate_for_system sets reasonable initial quantities" do
    # Clear existing inventory first
    @inventory.destroy
    
    inventories = MarketInventory.generate_for_system(@system)
    
    inventories.each do |inv|
      assert inv.quantity > 0, "#{inv.commodity} should have positive quantity"
      assert inv.quantity <= inv.max_quantity, "#{inv.commodity} quantity should not exceed max"
      assert inv.max_quantity >= 50, "#{inv.commodity} max_quantity should be at least 50"
      assert inv.restock_rate >= 5, "#{inv.commodity} restock_rate should be at least 5"
    end
  end

  test "generate_for_system is idempotent" do
    # Clear existing inventory first
    @inventory.destroy
    
    first_gen = MarketInventory.generate_for_system(@system)
    second_gen = MarketInventory.generate_for_system(@system)
    
    assert_equal first_gen.count, second_gen.count
    assert_equal first_gen.map(&:id).sort, second_gen.map(&:id).sort
  end

  test "for_system_commodity returns existing inventory" do
    found = MarketInventory.for_system_commodity(@system, "iron")
    assert_equal @inventory, found
  end

  test "for_system_commodity generates if not found" do
    # Clear existing and create fresh
    @inventory.destroy
    
    found = MarketInventory.for_system_commodity(@system, "copper")
    assert_not_nil found
    assert_equal "copper", found.commodity
    assert found.persisted?
  end
end
