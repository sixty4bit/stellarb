# frozen_string_literal: true

require "test_helper"

class BuildingUpgradeTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @building = buildings(:mining_facility)
    @user.update!(credits: 100_000)  # Enough for upgrades
  end

  # ===========================================
  # Upgrade Cost Calculation
  # ===========================================

  test "upgrade_cost returns cost difference to next tier" do
    @building.update!(tier: 1)
    
    current_cost = Building.cost_for(function: @building.function, tier: 1, race: @building.race)
    next_cost = Building.cost_for(function: @building.function, tier: 2, race: @building.race)
    expected_upgrade_cost = next_cost - current_cost
    
    assert_equal expected_upgrade_cost, @building.upgrade_cost
  end

  test "upgrade_cost returns nil for max tier building" do
    @building.update!(tier: 5)
    
    assert_nil @building.upgrade_cost
  end

  test "upgrade_cost scales with tier progression" do
    tier_1_building = Building.new(function: "extraction", tier: 1, race: "vex")
    tier_3_building = Building.new(function: "extraction", tier: 3, race: "vex")
    
    # Higher tier upgrades should cost more
    assert tier_3_building.upgrade_cost > tier_1_building.upgrade_cost
  end

  # ===========================================
  # Upgradeable Check
  # ===========================================

  test "upgradeable? returns true for active building below max tier" do
    @building.update!(tier: 1, status: "active", disabled_at: nil)
    
    assert @building.upgradeable?
  end

  test "upgradeable? returns false for max tier building" do
    @building.update!(tier: 5)
    
    refute @building.upgradeable?
  end

  test "upgradeable? returns false for disabled building" do
    @building.update!(tier: 1, disabled_at: Time.current)
    
    refute @building.upgradeable?
  end

  test "upgradeable? returns false for destroyed building" do
    @building.update!(tier: 1, status: "destroyed")
    
    refute @building.upgradeable?
  end

  test "upgradeable? returns false for building under construction" do
    @building.update!(tier: 1, status: "under_construction")
    
    refute @building.upgradeable?
  end

  # ===========================================
  # Upgrade Execution
  # ===========================================

  test "upgrade! increments tier" do
    @building.update!(tier: 2, status: "active")
    original_tier = @building.tier
    
    @building.upgrade!(user: @user)
    
    assert_equal original_tier + 1, @building.tier
  end

  test "upgrade! deducts credits from user" do
    @building.update!(tier: 1, status: "active")
    upgrade_cost = @building.upgrade_cost
    original_credits = @user.credits
    
    @building.upgrade!(user: @user)
    
    @user.reload
    assert_equal original_credits - upgrade_cost, @user.credits
  end

  test "upgrade! recalculates building attributes" do
    @building.update!(tier: 1, status: "active")
    original_durability = @building.building_attributes["durability"]
    
    @building.upgrade!(user: @user)
    
    assert @building.building_attributes["durability"] > original_durability,
      "Durability should increase after upgrade"
  end

  test "upgrade! raises error for max tier building" do
    @building.update!(tier: 5)
    
    error = assert_raises(Building::UpgradeError) do
      @building.upgrade!(user: @user)
    end
    
    assert_match /max tier/i, error.message
  end

  test "upgrade! raises error for disabled building" do
    @building.update!(tier: 1, disabled_at: Time.current)
    
    error = assert_raises(Building::UpgradeError) do
      @building.upgrade!(user: @user)
    end
    
    assert_match /cannot upgrade/i, error.message
  end

  test "upgrade! raises error for insufficient credits" do
    @building.update!(tier: 1, status: "active")
    @user.update!(credits: 1)  # Not enough
    
    error = assert_raises(User::InsufficientCreditsError) do
      @building.upgrade!(user: @user)
    end
    
    assert_match /insufficient credits/i, error.message
  end

  test "upgrade! does not increment tier if credit deduction fails" do
    @building.update!(tier: 1, status: "active")
    @user.update!(credits: 1)
    original_tier = @building.tier
    
    assert_raises(User::InsufficientCreditsError) do
      @building.upgrade!(user: @user)
    end
    
    @building.reload
    assert_equal original_tier, @building.tier
  end

  # ===========================================
  # Building Attribute Regeneration
  # ===========================================

  test "regenerate_building_attributes! updates stats based on tier" do
    @building.update!(tier: 3)
    @building.regenerate_building_attributes!
    
    # Stats should scale with tier
    assert @building.building_attributes["maintenance_rate"] == 60  # 20 * tier
    assert @building.building_attributes["hardpoints"] == 3        # tier
    assert @building.building_attributes["storage_capacity"] == 3000  # 1000 * tier
    assert @building.building_attributes["power_consumption"] == 15   # 5 * tier
    assert @building.building_attributes["durability"] == 1500        # 500 * tier
  end

  test "regenerate_building_attributes! applies function bonuses" do
    extraction_building = Building.new(
      function: "extraction", tier: 2, race: "vex", 
      name: "Test", system: systems(:alpha_centauri), user: @user
    )
    extraction_building.regenerate_building_attributes!
    
    # Extraction gets 2x output rate
    base_output = 10 * (2 ** 1.5)
    expected_output = (base_output * 2).to_i
    assert_equal expected_output, extraction_building.building_attributes["output_rate"].to_i
  end

  test "regenerate_building_attributes! applies racial bonuses" do
    krog_building = Building.new(
      function: "defense", tier: 2, race: "krog",
      name: "Test", system: systems(:alpha_centauri), user: @user
    )
    krog_building.regenerate_building_attributes!
    
    # Krog gets 1.2x durability
    base_durability = 500 * 2 * 1.5  # tier * 1.5 for defense
    expected_durability = (base_durability * 1.2).to_i
    assert_equal expected_durability, krog_building.building_attributes["durability"].to_i
  end
end
