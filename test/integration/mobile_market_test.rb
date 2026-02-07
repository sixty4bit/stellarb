# frozen_string_literal: true

require "test_helper"

class MobileMarketTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 5000)
    @system = System.cradle

    Building.find_or_create_by!(
      user: @user, system: @system, function: "civic"
    ) { |b| b.name = "Test Market"; b.race = "vex"; b.tier = 1 }

    Ship.create!(
      name: "Trade Vessel", user: @user, race: "vex",
      hull_size: "transport", variant_idx: 0,
      fuel: 50, fuel_capacity: 100,
      status: "docked", current_system: @system,
      ship_attributes: { "cargo_capacity" => 200 }
    )

    SystemVisit.create!(
      user: @user, system: @system,
      first_visited_at: Time.current, last_visited_at: Time.current
    )

    available_minerals = MineralAvailability.for_system(
      star_type: @system.properties&.dig("star_type") || "yellow_dwarf",
      x: @system.x, y: @system.y, z: @system.z
    )
    available_minerals.each do |mineral|
      MarketInventory.find_or_create_by!(system: @system, commodity: mineral[:name]) do |inv|
        inv.quantity = 500; inv.max_quantity = 1000; inv.restock_rate = 10
      end
    end
  end

  test "market page renders mobile card layout and desktop grid layout" do
    sign_in_as(@user)
    get system_market_index_path(@system)

    assert_response :success
    assert_select ".market-desktop-grid"
    assert_select ".market-mobile-cards"
  end
end
