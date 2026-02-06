# frozen_string_literal: true

require "test_helper"

class MarketRestockJobTest < ActiveJob::TestCase
  setup do
    @system = System.cradle
    @iron = MarketInventory.create!(
      system: @system,
      commodity: "iron",
      quantity: 50,
      max_quantity: 100,
      restock_rate: 10
    )
    @copper = MarketInventory.create!(
      system: @system,
      commodity: "copper",
      quantity: 100, # Already at max
      max_quantity: 100,
      restock_rate: 15
    )
    @water = MarketInventory.create!(
      system: @system,
      commodity: "water",
      quantity: 0,
      max_quantity: 200,
      restock_rate: 20
    )
  end

  test "restocks inventories below max_quantity" do
    MarketRestockJob.perform_now

    @iron.reload
    @copper.reload
    @water.reload

    # Iron: 50 + 10 = 60
    assert_equal 60, @iron.quantity

    # Copper: already at max, unchanged
    assert_equal 100, @copper.quantity

    # Water: 0 + 20 = 20
    assert_equal 20, @water.quantity
  end

  test "does not overshoot max_quantity" do
    @iron.update!(quantity: 95)
    
    MarketRestockJob.perform_now
    
    @iron.reload
    # 95 + 10 would be 105, but capped at 100
    assert_equal 100, @iron.quantity
  end

  test "handles empty inventory gracefully" do
    MarketInventory.delete_all
    
    # Should not raise
    assert_nothing_raised do
      MarketRestockJob.perform_now
    end
  end

  test "processes multiple systems" do
    other_system = System.create!(
      x: 10, y: 20, z: 30,
      name: "Test System",
      properties: { base_prices: { "fuel" => 30 } }
    )
    other_inventory = MarketInventory.create!(
      system: other_system,
      commodity: "fuel",
      quantity: 10,
      max_quantity: 100,
      restock_rate: 5
    )

    MarketRestockJob.perform_now

    @iron.reload
    other_inventory.reload

    assert_equal 60, @iron.quantity
    assert_equal 15, other_inventory.quantity
  end
end
