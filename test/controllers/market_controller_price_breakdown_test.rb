# frozen_string_literal: true

require "test_helper"

class MarketControllerPriceBreakdownTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @system = System.create!(
      name: "Breakdown Test System",
      short_id: "sy-bd-#{SecureRandom.hex(4)}",
      x: rand(1000),
      y: rand(1000),
      z: rand(1000),
      properties: {
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron", "copper"], "abundance" => "high" }
        },
        "base_prices" => { "iron" => 100, "copper" => 150 },
        "star_type" => "yellow_dwarf"
      }
    )

    # Create a marketplace so trading is enabled
    Building.create!(
      user: @user,
      system: @system,
      name: "Market Hub",
      function: "civic",
      race: "vex",
      tier: 1,
      status: "active",
      uuid: Building.generate_uuid7
    )

    # Create a visit record for the user
    SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 1.hour.ago,
      last_visited_at: 1.minute.ago,
      visit_count: 1
    )

    # Create a ship docked at the system for live prices
    ship = ships(:hauler)
    ship.update!(
      current_system: @system,
      user: @user,
      status: "docked"
    )

    sign_in_as @user
  end

  test "market index includes price breakdown in market data" do
    get system_market_index_path(@system)

    assert_response :success
    # Check that price breakdown elements are present in the view
    assert_select ".price-breakdown", { minimum: 1 }, "View should have price breakdown elements"
  end

  test "market index shows base price in view" do
    get system_market_index_path(@system)

    assert_response :success
    assert_select "span.base-price", { text: /100/ }, "View should show base price"
  end

  test "market index shows abundance modifier in view" do
    get system_market_index_path(@system)

    assert_response :success
    # Iron has "high" abundance = 0.8 modifier (-20%)
    assert_select "span.abundance-modifier", { text: /-20%/ }, "View should show abundance modifier"
  end

  test "market index shows building effects when present" do
    # Create a mine that affects iron price
    Building.create!(
      user: @user,
      system: @system,
      name: "Iron Extractor",
      function: "extraction",
      race: "vex",
      tier: 2,
      status: "active",
      specialization: "iron",
      uuid: Building.generate_uuid7
    )

    get system_market_index_path(@system)

    assert_response :success
    assert_select "span.building-effect", { text: /Iron Extractor/ }, "View should show building name"
    assert_select "span.building-effect", { text: /-10%/ }, "View should show building modifier"
  end

  test "market index shows final price calculation" do
    get system_market_index_path(@system)

    assert_response :success
    # Iron: base 100, abundance 0.8 = 80
    assert_select "span.final-price", { text: /80/ }, "View should show final calculated price"
  end
end
