# frozen_string_literal: true

require "test_helper"

class ShipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    sign_in_as(@user)
  end

  # Screen 9: Ships List
  test "index renders ships list" do
    get ships_path
    assert_response :success
    assert_select "h1", text: /Ships/
  end

  test "index shows user ships" do
    get ships_path
    assert_response :success
    assert_select "a", text: /Stellar Hauler/
  end

  test "index displays ship status" do
    get ships_path
    assert_response :success
    assert_select "*", text: /DOCKED/i
  end

  test "index shows ship hull size" do
    get ships_path
    assert_response :success
    assert_select "*", text: /transport/i
  end

  test "index has navigation to trading" do
    get ships_path
    assert_response :success
    assert_select "a[href='#{trading_ships_path}']"
  end

  test "index has navigation to combat" do
    get ships_path
    assert_response :success
    assert_select "a[href='#{combat_ships_path}']"
  end

  # Screen 10: Ship Detail
  test "show renders ship detail" do
    get ship_path(@ship)
    assert_response :success
    assert_select "h1", text: /Stellar Hauler/
  end

  test "show displays ship stats" do
    get ship_path(@ship)
    assert_response :success
    assert_select "*", text: /Cargo Capacity/i
  end

  test "show displays fuel level" do
    get ship_path(@ship)
    assert_response :success
    assert_select "*", text: /Fuel/i
  end

  test "show displays current location" do
    get ship_path(@ship)
    assert_response :success
    assert_select "*", text: /The Cradle/i
  end

  test "show has back to ships link" do
    get ship_path(@ship)
    assert_response :success
    assert_select "a[href='#{ships_path}']"
  end

  test "show has crew management section" do
    get ship_path(@ship)
    assert_response :success
    assert_select "*", text: /Crew/i
  end

  # Screen 11: Trading
  test "trading renders trading screen" do
    get trading_ships_path
    assert_response :success
    assert_select "h1", text: /Trading/i
  end

  test "trading shows route management options" do
    get trading_ships_path
    assert_response :success
    assert_select "a[href='#{routes_path}']"
  end

  # Screen 13: Combat
  test "combat renders combat screen" do
    get combat_ships_path
    assert_response :success
    assert_select "h1", text: /Combat/i
  end

  test "combat shows combat-ready ships" do
    get combat_ships_path
    assert_response :success
    # Should list ships with hardpoints
    assert_select "*", text: /Iron Fist/i
  end

  # Refueling UI Tests (4s1.1)
  test "show displays refuel form when docked" do
    get ship_path(@ship)
    assert_response :success
    assert_select "form[action='#{refuel_ship_path(@ship)}']"
    assert_select "input[name='amount']"
  end

  test "show displays current fuel price" do
    get ship_path(@ship)
    assert_response :success
    assert_select "*", text: /Fuel Price/i
  end

  test "refuel increases ship fuel" do
    @ship.update!(fuel: 50.0)
    @user.update!(credits: 5000)

    post refuel_ship_path(@ship), params: { amount: 10 }
    
    @ship.reload
    assert_equal 60.0, @ship.fuel
  end

  test "refuel deducts credits from user" do
    @ship.update!(fuel: 50.0)
    initial_credits = 5000
    @user.update!(credits: initial_credits)
    fuel_price = @ship.current_fuel_price

    post refuel_ship_path(@ship), params: { amount: 10 }

    @user.reload
    expected_credits = initial_credits - (10 * fuel_price)
    assert_equal expected_credits, @user.credits
  end

  test "refuel fails with insufficient credits" do
    @ship.update!(fuel: 50.0)
    @user.update!(credits: 1) # Not enough credits

    post refuel_ship_path(@ship), params: { amount: 10 }

    @ship.reload
    assert_equal 50.0, @ship.fuel # Should not change
  end

  test "refuel fails when not docked" do
    @ship.update!(
      status: "in_transit",
      destination_system: systems(:alpha_centauri),
      arrival_at: 1.hour.from_now
    )
    @user.update!(credits: 5000)

    post refuel_ship_path(@ship), params: { amount: 10 }

    assert_redirected_to ship_path(@ship)
    follow_redirect!
    assert_match /must be docked/i, response.body
  end
end
