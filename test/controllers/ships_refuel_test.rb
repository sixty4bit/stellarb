# frozen_string_literal: true

require "test_helper"

class ShipsRefuelTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 10000)
    
    @system = systems(:cradle)
    
    @ship = Ship.create!(
      name: "Refuel Test Ship",
      user: @user,
      race: "vex",
      hull_size: "scout",
      variant_idx: 1,
      fuel: 20,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system
    )
    
    sign_in_as @user
  end

  test "refuel success increases fuel and deducts credits" do
    initial_credits = @user.credits
    initial_fuel = @ship.fuel
    amount = 30
    
    post refuel_ship_path(@ship), params: { amount: amount }
    
    @ship.reload
    @user.reload
    
    assert_redirected_to ship_path(@ship)
    assert_equal initial_fuel + amount, @ship.fuel
    assert @user.credits < initial_credits, "Credits should be deducted"
    assert_match /refuel/i, flash[:notice]
  end

  test "refuel fails if insufficient credits" do
    @user.update!(credits: 1)  # Very low credits
    
    post refuel_ship_path(@ship), params: { amount: 50 }
    
    @ship.reload
    
    assert_redirected_to ship_path(@ship)
    assert_equal 20, @ship.fuel  # Unchanged
    assert_match /insufficient/i, flash[:alert]
  end

  test "refuel fails if ship not docked" do
    @ship.update!(status: "in_transit", destination_system: systems(:alpha_centauri), arrival_at: 1.hour.from_now)
    
    post refuel_ship_path(@ship), params: { amount: 30 }
    
    @ship.reload
    
    assert_redirected_to ship_path(@ship)
    assert_equal 20, @ship.fuel  # Unchanged
    assert_match /docked/i, flash[:alert]
  end

  test "refuel fails if exceeds fuel capacity" do
    post refuel_ship_path(@ship), params: { amount: 200 }  # Way over capacity
    
    @ship.reload
    
    assert_redirected_to ship_path(@ship)
    assert_equal 20, @ship.fuel  # Unchanged
    assert_match /capacity/i, flash[:alert]
  end

  test "refuel to full works" do
    initial_credits = @user.credits
    
    post refuel_ship_path(@ship), params: { amount: @ship.fuel_needed_to_fill }
    
    @ship.reload
    @user.reload
    
    assert_redirected_to ship_path(@ship)
    assert_equal @ship.fuel_capacity, @ship.fuel
    assert @user.credits < initial_credits
  end

  private

  def sign_in_as(user)
    post sessions_path, params: { user: { email: user.email } }
  end
end
