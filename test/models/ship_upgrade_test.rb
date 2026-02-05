# frozen_string_literal: true

require "test_helper"

class ShipUpgradeTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    @user.update!(credits: 50000)
  end

  # ===========================================
  # Upgrade Configuration
  # ===========================================

  test "UPGRADE_COSTS constant exists" do
    assert Ship::UPGRADE_COSTS.is_a?(Hash)
  end

  test "has upgrade costs for key attributes" do
    %w[cargo_capacity fuel_efficiency maneuverability hardpoints hull_points sensor_range].each do |attr|
      assert Ship::UPGRADE_COSTS.key?(attr),
        "Missing upgrade cost for: #{attr}"
    end
  end

  # ===========================================
  # Upgrade Calculations
  # ===========================================

  test "upgrade_cost_for calculates cost for attribute upgrade" do
    cost = @ship.upgrade_cost_for("cargo_capacity")
    assert cost.is_a?(Integer)
    assert cost > 0
  end

  test "upgrade_cost_for scales with upgrade count" do
    # More upgrades = higher cost for next upgrade
    cost_first = @ship.upgrade_cost_for("cargo_capacity")
    
    # Simulate having done 2 upgrades already
    @ship.ship_attributes["upgrades"] = { "cargo_capacity" => 2 }
    cost_after_upgrades = @ship.upgrade_cost_for("cargo_capacity")
    
    assert cost_after_upgrades > cost_first
  end

  test "upgrade_cost_for raises for invalid attribute" do
    assert_raises(ArgumentError) do
      @ship.upgrade_cost_for("invalid_attribute")
    end
  end

  # ===========================================
  # Upgradable Attributes
  # ===========================================

  test "upgradable_attributes returns list of upgradable attributes" do
    attrs = @ship.upgradable_attributes
    assert attrs.is_a?(Array)
    assert attrs.any?
  end

  test "upgradable attributes include cost and current value" do
    attrs = @ship.upgradable_attributes
    
    attrs.each do |attr|
      assert attr[:name].present?, "Missing name"
      assert attr[:current_value].present?, "Missing current_value"
      assert attr[:cost].is_a?(Integer), "Missing or invalid cost"
      assert attr[:upgrade_amount].present?, "Missing upgrade_amount"
    end
  end

  # ===========================================
  # Ship Upgrade Operation
  # ===========================================

  test "upgrade! increases attribute value" do
    initial_cargo = @ship.ship_attributes["cargo_capacity"]
    
    result = @ship.upgrade!("cargo_capacity", @user)
    
    assert result.success?
    assert @ship.ship_attributes["cargo_capacity"] > initial_cargo
  end

  test "upgrade! deducts credits from user" do
    initial_credits = @user.credits
    cost = @ship.upgrade_cost_for("cargo_capacity")
    
    @ship.upgrade!("cargo_capacity", @user)
    
    @user.reload
    assert_equal initial_credits - cost, @user.credits
  end

  test "upgrade! fails with insufficient credits" do
    @user.update!(credits: 1)
    
    result = @ship.upgrade!("cargo_capacity", @user)
    
    refute result.success?
    assert_match /insufficient/i, result.error
  end

  test "upgrade! fails for invalid attribute" do
    result = @ship.upgrade!("invalid_attr", @user)
    
    refute result.success?
    assert_match /invalid/i, result.error
  end

  test "upgrade! persists ship changes" do
    @ship.upgrade!("cargo_capacity", @user)
    @ship.reload
    
    # Value should be persisted
    assert @ship.ship_attributes["cargo_capacity"] > 100  # Initial from fixture
  end

  # ===========================================
  # Upgrade Limits
  # ===========================================

  test "can_upgrade? returns true when under limit" do
    assert @ship.can_upgrade?("cargo_capacity")
  end

  test "ships have maximum upgrade levels per attribute" do
    # Each attribute has a max upgrade based on hull size
    assert Ship::MAX_UPGRADES.is_a?(Hash)
    Ship::HULL_SIZES.each do |size|
      assert Ship::MAX_UPGRADES.key?(size)
    end
  end

  test "upgrade! fails when max upgrades reached" do
    # Set upgrade count to max
    @ship.ship_attributes["upgrades"] ||= {}
    @ship.ship_attributes["upgrades"]["cargo_capacity"] = Ship::MAX_UPGRADES[@ship.hull_size]
    @ship.save!
    
    result = @ship.upgrade!("cargo_capacity", @user)
    
    refute result.success?
    assert_match /maximum|limit/i, result.error
  end
end
