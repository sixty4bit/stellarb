# frozen_string_literal: true

require "test_helper"

class MarketControllerComponentsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 100_000)
    @system = System.cradle

    # Create a marketplace (civic building) - required for factories
    @marketplace = Building.find_or_create_by!(
      user: @user,
      system: @system,
      function: "civic"
    ) do |b|
      b.name = "Cradle Central Market"
      b.race = "vex"
      b.tier = 1
    end

    # Create a ship with cargo space
    @ship = Ship.create!(
      name: "Trade Vessel",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      ship_attributes: { "cargo_capacity" => 200 }
    )

    # Mark system as visited
    SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current
    )

    sign_in_as @user
  end

  # ===========================================
  # Components hidden without matching factory
  # ===========================================

  test "market does not show components without factory" do
    get system_market_index_path(@system)

    assert_response :success

    # Should not show any component names
    Components::ALL.each do |component|
      assert_no_match(/#{Regexp.escape(component[:name])}/i, response.body,
        "Component '#{component[:name]}' should NOT appear without factory")
    end
  end

  test "market shows only minerals without factory" do
    get system_market_index_path(@system)

    assert_response :success

    # Should show minerals
    assert_match(/iron/i, response.body)
  end

  # ===========================================
  # Matching factory type makes components visible
  # ===========================================

  test "electronics factory makes electronics components visible" do
    # Create electronics factory
    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 1
    )

    get system_market_index_path(@system)

    assert_response :success

    # Should show electronics components
    Components::ELECTRONICS.each do |component|
      assert_match(/#{Regexp.escape(component[:name])}/i, response.body,
        "Electronics component '#{component[:name]}' should appear with electronics factory")
    end
  end

  test "electronics factory does not make weapons components visible" do
    # Create electronics factory only
    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 1
    )

    get system_market_index_path(@system)

    assert_response :success

    # Should NOT show weapons components
    Components::WEAPONS.each do |component|
      assert_no_match(/#{Regexp.escape(component[:name])}/i, response.body,
        "Weapons component '#{component[:name]}' should NOT appear with only electronics factory")
    end
  end

  test "multiple factories make multiple component categories visible" do
    # Create both electronics and weapons factories
    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 1
    )

    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "weapons",
      name: "Weapons Factory",
      race: "krog",
      tier: 1
    )

    get system_market_index_path(@system)

    assert_response :success

    # Should show both electronics and weapons components
    Components::ELECTRONICS.each do |component|
      assert_match(/#{Regexp.escape(component[:name])}/i, response.body)
    end
    Components::WEAPONS.each do |component|
      assert_match(/#{Regexp.escape(component[:name])}/i, response.body)
    end

    # But NOT advanced components
    Components::ADVANCED.each do |component|
      assert_no_match(/#{Regexp.escape(component[:name])}/i, response.body)
    end
  end

  test "disabled factory does not make components visible" do
    # Create disabled electronics factory
    factory = Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 1
    )
    factory.update!(disabled_at: Time.current)

    get system_market_index_path(@system)

    assert_response :success

    # Should NOT show electronics components
    Components::ELECTRONICS.each do |component|
      assert_no_match(/#{Regexp.escape(component[:name])}/i, response.body,
        "Component '#{component[:name]}' should NOT appear with disabled factory")
    end
  end

  # ===========================================
  # Factory tier affects component stock levels
  # ===========================================

  test "higher tier factory produces higher stock levels" do
    # Create T1 electronics factory
    factory = Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 1
    )

    get system_market_index_path(@system)
    assert_response :success

    # Capture T1 inventory level from market data
    market_data_t1 = @controller.instance_variable_get(:@market_data)
    component = Components::ELECTRONICS.first
    t1_item = market_data_t1.find { |m| m[:commodity] == component[:name] }
    t1_inventory = t1_item[:inventory]

    # Upgrade to T3
    factory.update!(tier: 3)

    get system_market_index_path(@system)
    assert_response :success

    market_data_t3 = @controller.instance_variable_get(:@market_data)
    t3_item = market_data_t3.find { |m| m[:commodity] == component[:name] }
    t3_inventory = t3_item[:inventory]

    assert_operator t3_inventory, :>, t1_inventory,
      "T3 factory should produce more stock (#{t3_inventory}) than T1 (#{t1_inventory})"
  end

  test "T5 factory has highest component stock" do
    # Create T5 electronics factory
    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 5
    )

    get system_market_index_path(@system)
    assert_response :success

    market_data = @controller.instance_variable_get(:@market_data)
    component = Components::ELECTRONICS.first
    item = market_data.find { |m| m[:commodity] == component[:name] }

    # T5 should have substantial stock
    assert_operator item[:inventory], :>=, 100,
      "T5 factory should produce at least 100 units"
  end

  # ===========================================
  # Component trading
  # ===========================================

  test "can buy components when factory exists" do
    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 3
    )

    component_name = Components::ELECTRONICS.first[:name]

    post buy_system_market_index_path(@system), params: {
      commodity: component_name,
      quantity: 5
    }

    assert_redirected_to system_market_index_path(@system)
    assert_equal 5, @ship.reload.cargo[component_name]
  end

  test "cannot buy components without factory" do
    component_name = Components::ELECTRONICS.first[:name]

    post buy_system_market_index_path(@system), params: {
      commodity: component_name,
      quantity: 5
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /unknown commodity/i, flash[:alert]
  end

  test "can sell components when factory exists" do
    Building.create!(
      user: @user,
      system: @system,
      function: "refining",
      specialization: "electronics",
      name: "Electronics Factory",
      race: "vex",
      tier: 3
    )

    component_name = Components::ELECTRONICS.first[:name]
    @ship.update!(cargo: { component_name => 10 })
    initial_credits = @user.credits

    post sell_system_market_index_path(@system), params: {
      commodity: component_name,
      quantity: 5
    }

    assert_redirected_to system_market_index_path(@system)
    assert_equal 5, @ship.reload.cargo[component_name]
    assert_operator @user.reload.credits, :>, initial_credits
  end
end
