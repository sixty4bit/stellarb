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

  test "Mira Station has cheap ore and expensive food" do
    Seeds::TalosArm.seed!
    
    mira = System.find_by(name: "Mira Station")
    assert mira, "Mira Station should exist"
    
    # Check price deltas create arbitrage opportunity
    ore_delta = PriceDelta.find_by(system: mira, commodity: "ore")
    food_delta = PriceDelta.find_by(system: mira, commodity: "food")
    
    assert_operator ore_delta.delta_cents, :<, 0, "Ore should be cheaper than base"
    assert_operator food_delta.delta_cents, :>, 0, "Food should be more expensive than base"
  end

  test "Verdant Gardens has cheap food and expensive ore" do
    Seeds::TalosArm.seed!
    
    verdant = System.find_by(name: "Verdant Gardens")
    assert verdant, "Verdant Gardens should exist"
    
    ore_delta = PriceDelta.find_by(system: verdant, commodity: "ore")
    food_delta = PriceDelta.find_by(system: verdant, commodity: "food")
    
    assert_operator ore_delta.delta_cents, :>, 0, "Ore should be more expensive"
    assert_operator food_delta.delta_cents, :<, 0, "Food should be cheaper"
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
    
    # Buy ore at Mira (cheap) and sell at Verdant (expensive)
    # Base price is 50, deltas in cents need to be converted
    mira_delta = PriceDelta.find_by(system: mira, commodity: "ore").delta_cents / 100.0
    verdant_delta = PriceDelta.find_by(system: verdant, commodity: "ore").delta_cents / 100.0
    
    ore_buy_price = 50 + mira_delta
    ore_sell_price = 50 + verdant_delta
    
    profit_per_unit = ore_sell_price - ore_buy_price
    assert_operator profit_per_unit, :>, 0, 
      "Should profit from buying ore at Mira (#{ore_buy_price}) and selling at Verdant (#{ore_sell_price})"
  end
end
