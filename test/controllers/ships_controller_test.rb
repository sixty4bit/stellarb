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
end
