# frozen_string_literal: true

require "test_helper"

class ShipsControllerPurchaseTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 5000)
    @system = System.cradle
    sign_in_as(@user)
  end

  # Ship Purchase Form
  test "new shows purchase form" do
    get new_ship_path
    
    assert_response :success
    assert_select "h1", text: /Purchase Ship/i
  end

  test "new shows race options" do
    get new_ship_path
    
    assert_response :success
    Ship::RACES.each do |race|
      assert_select "option[value='#{race}']"
    end
  end

  test "new shows hull size options" do
    get new_ship_path
    
    assert_response :success
    Ship::HULL_SIZES.each do |hull|
      assert_select "option[value='#{hull}']"
    end
  end

  test "new shows user credits" do
    get new_ship_path
    
    assert_response :success
    assert_select "*", text: /5,000/
  end

  # Ship Creation
  test "create purchases ship and deducts credits" do
    initial_credits = @user.credits
    ship_cost = Ship.cost_for(hull_size: "scout", race: "myrmidon")
    
    assert_difference "Ship.count", 1 do
      post ships_path, params: {
        ship: { name: "New Ship", race: "myrmidon", hull_size: "scout" },
        system_id: @system.id
      }
    end
    
    assert_redirected_to Ship.last
    assert_equal initial_credits - ship_cost, @user.reload.credits
  end

  test "create sets ship at correct system" do
    post ships_path, params: {
      ship: { name: "Location Test", race: "vex", hull_size: "frigate" },
      system_id: @system.id
    }
    
    ship = Ship.find_by(name: "Location Test")
    assert_equal @system, ship.current_system
  end

  test "create defaults to The Cradle if no system specified" do
    post ships_path, params: {
      ship: { name: "Cradle Ship", race: "solari", hull_size: "scout" }
    }
    
    ship = Ship.find_by(name: "Cradle Ship")
    assert ship.current_system.is_cradle?
  end

  test "create fails with insufficient credits" do
    @user.update!(credits: 100)
    
    assert_no_difference "Ship.count" do
      post ships_path, params: {
        ship: { name: "Expensive Ship", race: "krog", hull_size: "titan" },
        system_id: @system.id
      }
    end
    
    assert_response :unprocessable_entity
    assert_select "*", text: /Insufficient credits/i
  end

  test "create fails with invalid race" do
    assert_no_difference "Ship.count" do
      post ships_path, params: {
        ship: { name: "Bad Race", race: "invalid", hull_size: "scout" },
        system_id: @system.id
      }
    end
    
    assert_response :unprocessable_entity
  end

  test "create fails with invalid hull size" do
    assert_no_difference "Ship.count" do
      post ships_path, params: {
        ship: { name: "Bad Hull", race: "vex", hull_size: "invalid" },
        system_id: @system.id
      }
    end
    
    assert_response :unprocessable_entity
  end

  test "create fails without name" do
    assert_no_difference "Ship.count" do
      post ships_path, params: {
        ship: { name: "", race: "vex", hull_size: "scout" },
        system_id: @system.id
      }
    end
    
    assert_response :unprocessable_entity
  end

  # Cost Calculations
  test "myrmidon ships cost 10% less" do
    myrmidon_cost = Ship.cost_for(hull_size: "scout", race: "myrmidon")
    vex_cost = Ship.cost_for(hull_size: "scout", race: "vex")
    
    assert_operator myrmidon_cost, :<, vex_cost
    assert_equal (vex_cost * 0.9).round, myrmidon_cost
  end

  test "krog ships cost 15% more" do
    krog_cost = Ship.cost_for(hull_size: "scout", race: "krog")
    vex_cost = Ship.cost_for(hull_size: "scout", race: "vex")
    
    assert_operator krog_cost, :>, vex_cost
    assert_equal (vex_cost * 1.15).round, krog_cost
  end
end
