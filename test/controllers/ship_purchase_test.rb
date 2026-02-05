# frozen_string_literal: true

require "test_helper"

class ShipPurchaseTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @user.update!(credits: 10000)
    @system = systems(:cradle)
    sign_in_as(@user)
  end

  # ===========================================
  # New Ship Form
  # ===========================================

  test "new shows ship purchase form" do
    get new_ship_path(system_id: @system.id)
    assert_response :success
    assert_select "form"
  end

  test "new displays available ship types" do
    get new_ship_path(system_id: @system.id)
    assert_response :success
    # Should show ship type options
    assert_select "*", text: /Scout/i
    assert_select "*", text: /Transport/i
  end

  test "new displays ship costs" do
    get new_ship_path(system_id: @system.id)
    assert_response :success
    # Should show costs
    assert_select "*", text: /500/  # Scout cost
  end

  test "new shows user credits" do
    get new_ship_path(system_id: @system.id)
    assert_response :success
    assert_select "*", text: /10,000|10000/  # User's credits
  end

  # ===========================================
  # Create Ship (Purchase)
  # ===========================================

  test "create purchases ship successfully" do
    assert_difference("Ship.count", 1) do
      post ships_path, params: {
        ship: {
          name: "My New Scout",
          hull_size: "scout",
          race: "vex"
        },
        system_id: @system.id
      }
    end

    assert_redirected_to ship_path(Ship.last)
    follow_redirect!
    assert_select "*", text: /purchased/i
  end

  test "create deducts credits from user" do
    initial_credits = @user.credits
    cost = Ship.cost_for(hull_size: "scout", race: "vex")

    post ships_path, params: {
      ship: {
        name: "My New Scout",
        hull_size: "scout",
        race: "vex"
      },
      system_id: @system.id
    }

    @user.reload
    assert_equal initial_credits - cost, @user.credits
  end

  test "create sets ship location to purchase system" do
    post ships_path, params: {
      ship: {
        name: "My New Scout",
        hull_size: "scout",
        race: "vex"
      },
      system_id: @system.id
    }

    ship = Ship.last
    assert_equal @system, ship.current_system
    assert_equal "docked", ship.status
  end

  test "create fails without sufficient credits" do
    @user.update!(credits: 10)

    assert_no_difference("Ship.count") do
      post ships_path, params: {
        ship: {
          name: "My New Titan",
          hull_size: "titan",
          race: "krog"
        },
        system_id: @system.id
      }
    end

    assert_response :unprocessable_entity
    assert_select "*", text: /insufficient|afford/i
  end

  test "create fails without ship name" do
    assert_no_difference("Ship.count") do
      post ships_path, params: {
        ship: {
          name: "",
          hull_size: "scout",
          race: "vex"
        },
        system_id: @system.id
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with invalid hull size" do
    assert_no_difference("Ship.count") do
      post ships_path, params: {
        ship: {
          name: "My Ship",
          hull_size: "invalid",
          race: "vex"
        },
        system_id: @system.id
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with invalid race" do
    assert_no_difference("Ship.count") do
      post ships_path, params: {
        ship: {
          name: "My Ship",
          hull_size: "scout",
          race: "invalid"
        },
        system_id: @system.id
      }
    end

    assert_response :unprocessable_entity
  end

  # ===========================================
  # Purchase From System Context
  # ===========================================

  test "new accepts system_id parameter" do
    get new_ship_path(system_id: @system.id)
    assert_response :success
    # Should show the system context
    assert_select "*", text: /#{@system.name}/i
  end
end
