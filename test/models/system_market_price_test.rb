# frozen_string_literal: true

require "test_helper"

class SystemMarketPriceTest < ActiveSupport::TestCase
  setup do
    @system = System.create!(
      name: "Test System",
      short_id: "sy-test-#{SecureRandom.hex(4)}",
      x: 100,
      y: 100,
      z: 100,
      properties: {
        "base_prices" => { "iron" => 100, "copper" => 150, "gold" => 500 },
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron"], "abundance" => "high" },
          "1" => { "minerals" => ["copper"], "abundance" => "low" },
          "2" => { "minerals" => ["gold"], "abundance" => "medium" }
        }
      }
    )
    @user = users(:pilot)
  end

  # ===========================================
  # abundance_modifier tests
  # ===========================================

  test "abundance_modifier returns 0.8 for high abundance" do
    modifier = @system.abundance_modifier("iron")

    assert_in_delta 0.8, modifier, 0.01
  end

  test "abundance_modifier returns 1.2 for low abundance" do
    modifier = @system.abundance_modifier("copper")

    assert_in_delta 1.2, modifier, 0.01
  end

  test "abundance_modifier returns 1.0 for medium abundance" do
    modifier = @system.abundance_modifier("gold")

    assert_in_delta 1.0, modifier, 0.01
  end

  test "abundance_modifier returns 1.0 for unknown commodity" do
    modifier = @system.abundance_modifier("nonexistent")

    assert_in_delta 1.0, modifier, 0.01
  end

  test "abundance_modifier returns 1.0 when mineral distribution is missing" do
    @system.update!(properties: { "base_prices" => { "iron" => 100 } })

    modifier = @system.abundance_modifier("iron")

    assert_in_delta 1.0, modifier, 0.01
  end

  # ===========================================
  # calculate_market_price tests
  # ===========================================

  test "calculate_market_price applies base price only when no buildings" do
    # Base price 100, abundance high (0.8), no buildings
    price = @system.calculate_market_price("iron")

    assert_equal 80, price  # 100 * 0.8 = 80
  end

  test "calculate_market_price applies single building modifier" do
    # Create a mine that reduces iron price by 5% per tier
    mine = @system.buildings.create!(
      user: @user,
      name: "Iron Mine",
      race: "vex",
      function: "extraction",
      tier: 2,
      status: "active",
      specialization: "iron"
    )
    # Stub price_modifier_for to return 0.9 (10% reduction for tier 2)
    mine.define_singleton_method(:price_modifier_for) do |commodity|
      commodity == "iron" ? 0.9 : 1.0
    end

    # Force reload with our stubbed building
    @system.buildings.reset
    @system.instance_variable_set(:@_stubbed_buildings, [mine])
    @system.define_singleton_method(:buildings) { @_stubbed_buildings }

    price = @system.calculate_market_price("iron")

    # 100 (base) * 0.8 (abundance) * 0.9 (building) = 72
    assert_equal 72, price
  end

  test "calculate_market_price applies multiple building modifiers" do
    system = System.create!(
      name: "Industrial Hub",
      short_id: "sy-ind-#{SecureRandom.hex(4)}",
      x: 200,
      y: 200,
      z: 200,
      properties: {
        "base_prices" => { "iron" => 100 },
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron"], "abundance" => "medium" }
        }
      }
    )

    # Create mock buildings with modifiers using proper objects
    mock_class = Class.new do
      attr_reader :modifier_value

      def initialize(modifier)
        @modifier_value = modifier
      end

      def operational?
        true
      end

      def price_modifier_for(commodity)
        commodity == "iron" ? @modifier_value : 1.0
      end
    end

    building1 = mock_class.new(0.95)
    building2 = mock_class.new(0.90)

    system.define_singleton_method(:buildings) { [building1, building2] }

    price = system.calculate_market_price("iron")

    # 100 (base) * 1.0 (abundance medium) * 0.95 * 0.90 = 85.5 -> 86
    assert_equal 86, price
  end

  test "calculate_market_price ignores non-operational buildings" do
    system = System.create!(
      name: "Damaged System",
      short_id: "sy-dam-#{SecureRandom.hex(4)}",
      x: 300,
      y: 300,
      z: 300,
      properties: {
        "base_prices" => { "iron" => 100 },
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron"], "abundance" => "medium" }
        }
      }
    )

    # Mock building class
    mock_class = Class.new do
      attr_reader :is_operational, :modifier_value

      def initialize(operational, modifier)
        @is_operational = operational
        @modifier_value = modifier
      end

      def operational?
        @is_operational
      end

      def price_modifier_for(_commodity)
        @modifier_value
      end
    end

    # One operational (0.9 modifier), one disabled (0.5 modifier - should be ignored)
    operational = mock_class.new(true, 0.9)
    disabled = mock_class.new(false, 0.5)

    system.define_singleton_method(:buildings) { [operational, disabled] }

    price = system.calculate_market_price("iron")

    # 100 * 1.0 * 0.9 = 90 (disabled building ignored)
    assert_equal 90, price
  end

  test "calculate_market_price returns nil for unknown commodity" do
    price = @system.calculate_market_price("unobtainium")

    assert_nil price
  end

  test "calculate_market_price returns rounded integer" do
    system = System.create!(
      name: "Rounding Test",
      short_id: "sy-rnd-#{SecureRandom.hex(4)}",
      x: 400,
      y: 400,
      z: 400,
      properties: {
        "base_prices" => { "iron" => 100 },
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron"], "abundance" => "high" }
        }
      }
    )

    # 100 * 0.8 = 80 (should be integer)
    price = system.calculate_market_price("iron")

    assert_kind_of Integer, price
  end

  # ===========================================
  # Performance tests
  # ===========================================

  test "calculate_market_price completes in under 10ms" do
    # Create system with many buildings
    system = System.create!(
      name: "Busy System",
      short_id: "sy-busy-#{SecureRandom.hex(4)}",
      x: 800,
      y: 800,
      z: 800,
      properties: {
        "base_prices" => { "iron" => 100, "copper" => 150, "gold" => 500 },
        "mineral_distribution" => {
          "0" => { "minerals" => ["iron", "copper", "gold"], "abundance" => "medium" }
        }
      }
    )

    # Create a civic building first (required for refining)
    system.buildings.create!(
      user: @user,
      name: "Marketplace",
      race: "vex",
      function: "civic",
      tier: 1,
      status: "active"
    )

    # Add various buildings
    10.times do |i|
      system.buildings.create!(
        user: @user,
        name: "Defense #{i}",
        race: "vex",
        function: "defense",
        tier: (i % 5) + 1,
        status: "active"
      )
    end

    start_time = Time.now
    100.times { system.calculate_market_price("iron") }
    elapsed = (Time.now - start_time) * 1000 / 100  # Average ms per call

    assert elapsed < 10, "Expected < 10ms, got #{elapsed.round(2)}ms"
  end
end
