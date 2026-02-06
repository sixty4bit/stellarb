# frozen_string_literal: true

require "test_helper"

class MarketControllerMarketplaceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(credits: 5000)

    # Create a system (NOT The Cradle) so we control marketplace presence
    @system = System.create!(
      name: "Trade Station Alpha",
      short_id: "sy-trade-alpha-#{SecureRandom.hex(4)}",
      x: 100,
      y: 100,
      z: 100,
      properties: {
        star_type: "yellow_dwarf",
        planet_count: 3,
        hazard_level: 0,
        base_prices: { "ore" => 100, "fuel" => 200, "iron" => 50 },
        mineral_distribution: {
          "0" => { "minerals" => %w[iron copper], "abundance" => "common" }
        }
      }
    )

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

    # Create market inventory
    @system.base_prices.each do |commodity, _price|
      MarketInventory.create!(
        system: @system,
        commodity: commodity,
        quantity: 500,
        max_quantity: 1000,
        restock_rate: 10
      )
    end

    sign_in_as @user
  end

  # =========================================
  # TRADING DISABLED WITHOUT MARKETPLACE
  # =========================================

  test "index shows trading disabled message when no marketplace" do
    get system_market_index_path(@system)

    assert_response :success
    assert_select ".trading-disabled", count: 1
  end

  test "buy fails when no marketplace exists" do
    post buy_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /marketplace.*required|trading.*disabled|no marketplace/i, flash[:alert]
    assert_nil @ship.reload.cargo["ore"]
  end

  test "sell fails when no marketplace exists" do
    @ship.update!(cargo: { "ore" => 50 })

    post sell_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /marketplace.*required|trading.*disabled|no marketplace/i, flash[:alert]
    assert_equal 50, @ship.reload.cargo["ore"]  # Unchanged
  end

  # =========================================
  # TRADING ENABLED WITH MARKETPLACE
  # =========================================

  test "buy succeeds when marketplace exists" do
    create_marketplace(tier: 1)

    post buy_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /purchased/i, flash[:notice]
    assert_equal 10, @ship.reload.cargo["ore"]
  end

  test "sell succeeds when marketplace exists" do
    create_marketplace(tier: 1)
    @ship.update!(cargo: { "ore" => 50 })

    post sell_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /sold/i, flash[:notice]
    assert_equal 40, @ship.reload.cargo["ore"]
  end

  # =========================================
  # DISABLED/DESTROYED MARKETPLACE
  # =========================================

  test "buy fails when marketplace is disabled" do
    marketplace = create_marketplace(tier: 1)
    marketplace.update!(disabled_at: Time.current)

    post buy_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /marketplace.*required|trading.*disabled|no marketplace/i, flash[:alert]
  end

  test "sell fails when marketplace is destroyed" do
    marketplace = create_marketplace(tier: 1)
    marketplace.update!(status: "destroyed")
    @ship.update!(cargo: { "ore" => 50 })

    post sell_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    assert_match /marketplace.*required|trading.*disabled|no marketplace/i, flash[:alert]
  end

  # =========================================
  # MARKETPLACE FEE APPLIED TO TRADES
  # =========================================

  test "marketplace fee is deducted from buy transaction" do
    create_marketplace(tier: 1)  # 5% fee
    initial_credits = @user.credits.to_i

    # ore base price is 100, buy price = 100 * 1.10 = 110
    # With 5% marketplace fee on 10 units: 110 * 10 = 1100
    # Fee: 1100 * 0.05 = 55
    # Total: 1100 + 55 = 1155

    post buy_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    # The total deducted should include the marketplace fee
    total_deducted = initial_credits - @user.reload.credits.to_i
    # Base cost without fee: 1100
    # With 5% fee: 1155
    assert_equal 1155, total_deducted
  end

  test "higher tier marketplace charges lower fee" do
    create_marketplace(tier: 5)  # 1% fee
    initial_credits = @user.credits.to_i

    # ore base price is 100, buy price = 100 * 1.10 = 110
    # With 1% marketplace fee on 10 units: 110 * 10 = 1100
    # Fee: 1100 * 0.01 = 11
    # Total: 1100 + 11 = 1111

    post buy_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    total_deducted = initial_credits - @user.reload.credits.to_i
    assert_equal 1111, total_deducted
  end

  test "marketplace fee is deducted from sell proceeds" do
    create_marketplace(tier: 1)  # 5% fee
    @ship.update!(cargo: { "ore" => 50 })
    initial_credits = @user.credits.to_i

    # ore base price is 100, sell price = 100 * 0.90 = 90
    # Gross income: 90 * 10 = 900
    # Fee: 900 * 0.05 = 45
    # Net income: 900 - 45 = 855

    post sell_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    total_earned = @user.reload.credits.to_i - initial_credits
    assert_equal 855, total_earned
  end

  test "notice message includes marketplace fee information" do
    create_marketplace(tier: 1)

    post buy_system_market_index_path(@system), params: {
      commodity: "ore",
      quantity: 10
    }

    assert_redirected_to system_market_index_path(@system)
    # Should mention fee in the notice
    assert_match /fee/i, flash[:notice]
  end

  private

  def create_marketplace(tier:)
    Building.create!(
      user: @user,
      system: @system,
      name: "Central Market T#{tier}",
      function: "civic",
      race: "vex",
      tier: tier
    )
  end
end
