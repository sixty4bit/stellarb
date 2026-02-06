# frozen_string_literal: true

require "test_helper"

class BuildingConstructionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @user.update!(credits: 50000)
    @system = systems(:cradle)
    sign_in_as(@user)
  end

  # ===========================================
  # New Building Form
  # ===========================================

  test "new shows building construction form" do
    get new_building_path(system_id: @system.id)
    assert_response :success
    assert_select "form"
  end

  test "new displays available building types" do
    get new_building_path(system_id: @system.id)
    assert_response :success
    # Should show function options
    assert_select "*", text: /Extraction/i
    assert_select "*", text: /Defense/i
  end

  test "new displays building costs" do
    get new_building_path(system_id: @system.id)
    assert_response :success
    # Should show costs (extraction tier 1 = 10,000 per source doc)
    assert_select "*", text: /10,000|10000/  # Extraction tier 1 cost
  end

  test "new shows user credits" do
    get new_building_path(system_id: @system.id)
    assert_response :success
    assert_select "*", text: /50,000|50000/  # User's credits
  end

  # ===========================================
  # Create Building (Construction)
  # ===========================================

  test "create constructs building successfully" do
    assert_difference("Building.count", 1) do
      post buildings_path, params: {
        building: {
          name: "My New Facility",
          function: "defense",
          tier: 1,
          race: "vex",
          system_id: @system.id
        }
      }
    end

    assert_redirected_to building_path(Building.last)
    follow_redirect!
    assert_select "*", text: /construction started/i
  end

  test "create deducts credits from user" do
    initial_credits = @user.credits
    cost = Building.cost_for(function: "defense", tier: 1, race: "vex")

    post buildings_path, params: {
      building: {
        name: "My New Facility",
        function: "defense",
        tier: 1,
        race: "vex",
        system_id: @system.id
      }
    }

    @user.reload
    assert_equal initial_credits - cost, @user.credits
  end

  test "create sets building location to specified system" do
    post buildings_path, params: {
      building: {
        name: "My New Facility",
        function: "defense",
        tier: 1,
        race: "vex",
        system_id: @system.id
      }
    }

    building = Building.last
    assert_equal @system, building.system
  end

  test "create sets building status to under_construction" do
    post buildings_path, params: {
      building: {
        name: "My New Facility",
        function: "defense",
        tier: 1,
        race: "vex",
        system_id: @system.id
      }
    }

    building = Building.last
    assert_equal "under_construction", building.status
  end

  test "create fails without sufficient credits" do
    @user.update!(credits: 10)

    assert_no_difference("Building.count") do
      post buildings_path, params: {
        building: {
          name: "My Defense Platform",
          function: "defense",
          tier: 5,
          race: "krog",
          system_id: @system.id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "*", text: /insufficient|afford/i
  end

  test "create fails without building name" do
    assert_no_difference("Building.count") do
      post buildings_path, params: {
        building: {
          name: "",
          function: "defense",
          tier: 1,
          race: "vex",
          system_id: @system.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with invalid function" do
    assert_no_difference("Building.count") do
      post buildings_path, params: {
        building: {
          name: "My Facility",
          function: "invalid",
          tier: 1,
          race: "vex",
          system_id: @system.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with invalid race" do
    assert_no_difference("Building.count") do
      post buildings_path, params: {
        building: {
          name: "My Facility",
          function: "defense",
          tier: 1,
          race: "invalid",
          system_id: @system.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with invalid tier" do
    assert_no_difference("Building.count") do
      post buildings_path, params: {
        building: {
          name: "My Facility",
          function: "defense",
          tier: 0,
          race: "vex",
          system_id: @system.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # ===========================================
  # Construction From System Context
  # ===========================================

  test "new accepts system_id parameter" do
    get new_building_path(system_id: @system.id)
    assert_response :success
    # Should show the system context
    assert_select "*", text: /#{@system.name}/i
  end
end
