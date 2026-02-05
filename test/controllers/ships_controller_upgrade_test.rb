# frozen_string_literal: true

require "test_helper"

class ShipsControllerUpgradeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @user.update!(credits: 50000)
    @ship = ships(:hauler)
    sign_in_as(@user)
  end

  # ===========================================
  # Upgrade Action
  # ===========================================

  test "POST upgrade succeeds with valid attribute" do
    initial_cargo = @ship.ship_attributes["cargo_capacity"]
    
    post upgrade_ship_path(@ship, attribute: "cargo_capacity")
    
    assert_redirected_to @ship
    assert_match /upgraded/i, flash[:notice]
    
    @ship.reload
    assert @ship.ship_attributes["cargo_capacity"] > initial_cargo
  end

  test "POST upgrade deducts credits from user" do
    initial_credits = @user.credits
    cost = @ship.upgrade_cost_for("cargo_capacity")
    
    post upgrade_ship_path(@ship, attribute: "cargo_capacity")
    
    @user.reload
    assert_equal initial_credits - cost, @user.credits
  end

  test "POST upgrade fails with insufficient credits" do
    @user.update!(credits: 1)
    
    post upgrade_ship_path(@ship, attribute: "cargo_capacity")
    
    assert_redirected_to @ship
    assert_match /insufficient/i, flash[:alert]
  end

  test "POST upgrade fails with invalid attribute" do
    post upgrade_ship_path(@ship, attribute: "invalid_attr")
    
    assert_redirected_to @ship
    assert_match /invalid/i, flash[:alert]
  end

  test "POST upgrade fails when max upgrades reached" do
    # Set upgrade count to max
    @ship.ship_attributes["upgrades"] ||= {}
    @ship.ship_attributes["upgrades"]["cargo_capacity"] = Ship::MAX_UPGRADES[@ship.hull_size]
    @ship.save!
    
    post upgrade_ship_path(@ship, attribute: "cargo_capacity")
    
    assert_redirected_to @ship
    assert_match /maximum|limit/i, flash[:alert]
  end

  test "POST upgrade requires authentication" do
    reset!  # Clear session
    
    post upgrade_ship_path(@ship, attribute: "cargo_capacity")
    
    # Should redirect to login
    assert_response :redirect
  end

  test "cannot upgrade another user's ship" do
    other_user = users(:one)
    # Create a ship belonging to another user
    other_ship = Ship.create!(
      user: other_user,
      name: "Enemy Ship",
      short_id: "sh-ene",
      uuid: Ship.generate_uuid7,
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 50,
      status: "docked",
      current_system: systems(:cradle),
      ship_attributes: { cargo_capacity: 100, fuel_efficiency: 1.0, maneuverability: 50, hardpoints: 1, hull_points: 50, sensor_range: 10 }
    )
    
    # Integration tests return 404 response instead of raising exception
    post upgrade_ship_path(other_ship, attribute: "cargo_capacity")
    assert_response :not_found
  end
end
