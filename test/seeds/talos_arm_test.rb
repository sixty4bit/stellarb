# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/talos_arm"

class TalosArmSeedTest < ActiveSupport::TestCase
  setup do
    # Clean up any existing Talos Arm systems
    Seeds::TalosArm::SYSTEMS.each do |config|
      x, y, z = config[:coords]
      System.find_by(x: x, y: y, z: z)&.destroy
    end
  end

  test "seeding creates all Talos Arm systems" do
    Seeds::TalosArm.seed!
    
    Seeds::TalosArm::SYSTEMS.each do |config|
      x, y, z = config[:coords]
      system = System.find_by(x: x, y: y, z: z)
      
      assert system, "System at (#{x},#{y},#{z}) should exist"
      assert_equal config[:name], system.name
      assert system.properties["is_tutorial_zone"], "Should be marked as tutorial zone"
      assert system.properties["talos_arm"], "Should be marked as Talos Arm"
    end
  end

  test "Mira Station has cheap Iron and expensive Tungsten" do
    Seeds::TalosArm.seed!
    
    mira = System.find_by(name: "Mira Station")
    assert mira, "Mira Station should exist"
    
    # Check price deltas create arbitrage opportunity
    iron_delta = PriceDelta.find_by(system: mira, commodity: "Iron")
    tungsten_delta = PriceDelta.find_by(system: mira, commodity: "Tungsten")
    
    assert_not_nil iron_delta, "Iron should have a price delta"
    assert_not_nil tungsten_delta, "Tungsten should have a price delta"
    assert_operator iron_delta.delta_cents, :<, 0, "Iron should be cheaper than base"
    assert_operator tungsten_delta.delta_cents, :>, 0, "Tungsten should be more expensive than base"
  end

  test "Verdant Gardens has expensive Iron and cheap Carbon" do
    Seeds::TalosArm.seed!
    
    verdant = System.find_by(name: "Verdant Gardens")
    assert verdant, "Verdant Gardens should exist"
    
    iron_delta = PriceDelta.find_by(system: verdant, commodity: "Iron")
    carbon_delta = PriceDelta.find_by(system: verdant, commodity: "Carbon")
    
    assert_not_nil iron_delta, "Iron should have a price delta"
    assert_not_nil carbon_delta, "Carbon should have a price delta"
    assert_operator iron_delta.delta_cents, :>, 0, "Iron should be more expensive"
    assert_operator carbon_delta.delta_cents, :<, 0, "Carbon should be cheaper"
  end

  test "all Talos Arm systems are within 5 units of The Cradle" do
    Seeds::TalosArm.seed!
    cradle = System.cradle
    
    Seeds::TalosArm::SYSTEMS.each do |config|
      x, y, z = config[:coords]
      distance = Math.sqrt(x**2 + y**2 + z**2)
      
      assert_operator distance, :<=, 5, 
        "#{config[:name]} at (#{x},#{y},#{z}) should be within 5 units of Cradle (distance: #{distance.round(2)})"
    end
  end

  test "reset removes all Talos Arm systems" do
    Seeds::TalosArm.seed!
    
    # Verify systems exist
    initial_count = Seeds::TalosArm::SYSTEMS.count { |c| 
      x, y, z = c[:coords]
      System.find_by(x: x, y: y, z: z) 
    }
    assert_equal Seeds::TalosArm::SYSTEMS.length, initial_count
    
    Seeds::TalosArm.reset!
    
    # Verify systems are gone
    remaining = Seeds::TalosArm::SYSTEMS.count { |c|
      x, y, z = c[:coords]
      System.find_by(x: x, y: y, z: z)
    }
    assert_equal 0, remaining
  end

  test "profitable trade route exists between systems" do
    Seeds::TalosArm.seed!
    
    mira = System.find_by(name: "Mira Station")
    verdant = System.find_by(name: "Verdant Gardens")
    
    # Buy Iron at Mira (cheap) and sell at Verdant (expensive)
    # Base price is 10, deltas in cents need to be converted
    mira_delta = PriceDelta.find_by(system: mira, commodity: "Iron")
    verdant_delta = PriceDelta.find_by(system: verdant, commodity: "Iron")
    
    assert_not_nil mira_delta, "Mira should have Iron price delta"
    assert_not_nil verdant_delta, "Verdant should have Iron price delta"
    
    mira_adjustment = mira_delta.delta_cents / 100.0
    verdant_adjustment = verdant_delta.delta_cents / 100.0
    
    iron_buy_price = 10 + mira_adjustment
    iron_sell_price = 10 + verdant_adjustment
    
    profit_per_unit = iron_sell_price - iron_buy_price
    assert_operator profit_per_unit, :>, 0, 
      "Should profit from buying Iron at Mira (#{iron_buy_price}) and selling at Verdant (#{iron_sell_price})"
  end
end
