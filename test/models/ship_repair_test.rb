# frozen_string_literal: true

require "test_helper"

class ShipRepairTest < ActiveSupport::TestCase
  setup do
    @ship = ships(:hauler)
    @user = users(:pilot)
    # Ensure ship is docked and damaged
    @ship.update!(status: "docked")
    @ship.ship_attributes["hull_points"] = 50
    @ship.save!
  end

  test "damaged? returns true when hull_points below max" do
    assert @ship.damaged?
  end

  test "damaged? returns false at full hull" do
    @ship.ship_attributes["hull_points"] = @ship.max_hull_points
    @ship.save!
    refute @ship.damaged?
  end

  test "repair_cost calculates based on missing hull points" do
    missing = @ship.max_hull_points - 50
    assert_equal missing * Ship::REPAIR_COST_PER_POINT, @ship.repair_cost
  end

  test "repair! restores hull to max and deducts credits" do
    initial_credits = @user.credits
    cost = @ship.repair_cost

    result = @ship.repair!(@user)

    assert result.success?
    @ship.reload
    @user.reload
    assert_equal @ship.max_hull_points, @ship.hull_points
    assert_equal initial_credits - cost, @user.credits
  end

  test "repair! fails when ship is not docked" do
    @ship.update!(status: "in_transit")
    result = @ship.repair!(@user)
    refute result.success?
    assert_match /docked/, result.error
  end

  test "repair! fails when ship is not damaged" do
    @ship.ship_attributes["hull_points"] = @ship.max_hull_points
    @ship.save!
    result = @ship.repair!(@user)
    refute result.success?
    assert_match /full hull/, result.error
  end

  test "repair! fails with insufficient credits" do
    @user.update!(credits: 0)
    result = @ship.repair!(@user)
    refute result.success?
    assert_match /Insufficient credits/, result.error
  end
end
