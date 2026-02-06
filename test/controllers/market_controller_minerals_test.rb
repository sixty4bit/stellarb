# frozen_string_literal: true

require "test_helper"

class MarketControllerMineralsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 50000)
    @system = System.cradle
    
    # Create a ship docked at the system
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

  # =========================================
  # Mineral Availability Tests
  # =========================================

  test "market shows available minerals based on system type and distance" do
    get system_market_index_path(@system)
    
    assert_response :success
    # The Cradle is at (0,0,0) - should only have Tier 1-2 minerals
    assert_select "div.text-white.font-bold", text: "Iron"
    assert_select "div.text-white.font-bold", text: "Copper"
    
    # Should NOT show exotic or futuristic minerals near Cradle
    assert_select "div.text-white.font-bold", { text: "Stellarium", count: 0 }
    assert_select "div.text-white.font-bold", { text: "Uranium", count: 0 }
  end

  test "market displays mineral tier" do
    get system_market_index_path(@system)
    
    assert_response :success
    # Should show tier badges
    assert_select "span.tier-badge"
  end

  test "deep space system shows exotic and futuristic minerals" do
    # Create a system far from Cradle with neutron_star type
    deep_system = System.create!(
      name: "Deep Neutron",
      x: 6000, y: 0, z: 0,
      properties: {
        "star_type" => "neutron_star",
        "base_prices" => Minerals::ALL.each_with_object({}) { |m, h| h[m[:name]] = m[:base_price] }
      }
    )
    
    # Visit the system
    SystemVisit.create!(user: @user, system: deep_system, first_visited_at: Time.current, last_visited_at: Time.current)
    
    # Dock ship there
    @ship.update!(current_system: deep_system)
    
    # Create market inventories
    Minerals::ALL.each do |mineral|
      MarketInventory.find_or_create_by!(system: deep_system, commodity: mineral[:name]) do |inv|
        inv.quantity = 100
        inv.max_quantity = 1000
        inv.restock_rate = 10
      end
    end
    
    get system_market_index_path(deep_system)
    
    assert_response :success
    # Deep space neutron star should have exotic and futuristic minerals
    assert_select "div.text-white.font-bold", text: "Stellarium"  # Neutron star futuristic
    assert_select "div.text-white.font-bold", text: "Darkstone"   # Deep space (>5000 units)
    assert_select "div.text-white.font-bold", text: "Uranium"     # Exotic tier
    assert_select "div.text-white.font-bold", text: "Iron"        # Common tier (always available)
  end

  test "market filters commodities by system availability" do
    get system_market_index_path(@system)
    
    assert_response :success
    
    # Count minerals shown - should match MineralAvailability
    available = MineralAvailability.for_system(
      star_type: @system.properties&.dig("star_type") || "yellow_dwarf",
      x: @system.x,
      y: @system.y,
      z: @system.z
    )
    
    # Verify each available mineral name appears in the response
    available.each do |mineral|
      assert_match mineral[:name], response.body, "Market should show #{mineral[:name]}"
    end
    
    # Verify count in stats matches
    assert_select "div.text-2xl.font-bold", text: available.count.to_s
  end
end
