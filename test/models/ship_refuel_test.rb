require "test_helper"

class ShipRefuelTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(credits: 10000)  # Enough for refueling tests
    @system = System.cradle
    @ship = Ship.create!(
      name: "Test Hauler",
      user: @user,
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 10,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system
    )
  end

  test "refuel! adds fuel to ship" do
    initial_fuel = @ship.fuel
    result = @ship.refuel!(20, @user)

    assert result.success?
    assert_equal initial_fuel + 20, @ship.reload.fuel
  end

  test "refuel! deducts credits from user based on market price" do
    initial_credits = @user.credits
    fuel_amount = 5
    expected_cost = fuel_amount * @ship.current_fuel_price

    result = @ship.refuel!(fuel_amount, @user)

    assert result.success?
    assert_equal initial_credits - expected_cost, @user.reload.credits
  end

  test "refuel! fails if insufficient credits" do
    @user.update!(credits: 100)  # Only 100 credits
    
    result = @ship.refuel!(50, @user)  # Needs 5000 credits (50 * 100/unit)

    assert_not result.success?
    assert_match /insufficient credits/i, result.error
    assert_equal 10, @ship.reload.fuel # Fuel unchanged
  end

  test "refuel! fails if not docked at a system" do
    @ship.update!(status: "in_transit", current_system: nil, 
                  destination_system: @system, 
                  location_x: 0, location_y: 0, location_z: 0)

    result = @ship.refuel!(10, @user)

    assert_not result.success?
    assert_match /must be docked/i, result.error
  end

  test "refuel! fails if amount would exceed fuel capacity" do
    @ship.update!(fuel: 90)
    
    result = @ship.refuel!(20, @user)

    assert_not result.success?
    assert_match /exceed.*capacity/i, result.error
  end

  test "refuel_to_full! caps at fuel capacity" do
    @ship.update!(fuel: 90)
    
    result = @ship.refuel_to_full!(@user)

    assert result.success?
    assert_equal 100, @ship.reload.fuel
  end

  test "current_fuel_price returns system market fuel price" do
    price = @ship.current_fuel_price
    
    assert price.positive?
  end

  test "fuel_needed_to_fill returns correct amount" do
    @ship.update!(fuel: 30)
    
    assert_equal 70, @ship.fuel_needed_to_fill
  end

  test "refuel_cost_for calculates total cost correctly" do
    amount = 10
    price = @ship.current_fuel_price
    
    assert_equal amount * price, @ship.refuel_cost_for(amount)
  end
end
