# frozen_string_literal: true

require "test_helper"

class GrantCalculatorTest < ActiveSupport::TestCase
  # From ROADMAP Section 3.4: The Grant is 10,000 credits
  # Must be enough for exploration ship + crew

  test "GRANT_AMOUNT is 10,000 credits as per roadmap" do
    assert_equal 10_000, GrantCalculator::GRANT_AMOUNT
  end

  test "EXPLORATION_SHIP_COST covers a basic scout ship" do
    # Scout is the cheapest hull, suitable for Phase 2 exploration
    assert GrantCalculator::EXPLORATION_SHIP_COST > 0
    assert GrantCalculator::EXPLORATION_SHIP_COST <= 5_000
  end

  test "MINIMUM_CREW_COST covers hiring at least 2 crew members" do
    # Scout requires 1-2 crew per Ship model
    assert GrantCalculator::MINIMUM_CREW_COST > 0
    assert GrantCalculator::MINIMUM_CREW_COST <= 2_000
  end

  test "grant amount covers ship plus crew with buffer" do
    total_minimum = GrantCalculator::EXPLORATION_SHIP_COST + GrantCalculator::MINIMUM_CREW_COST
    assert GrantCalculator::GRANT_AMOUNT >= total_minimum,
           "Grant (#{GrantCalculator::GRANT_AMOUNT}) must cover ship (#{GrantCalculator::EXPLORATION_SHIP_COST}) + crew (#{GrantCalculator::MINIMUM_CREW_COST})"
  end

  test "grant leaves operating capital after minimum purchase" do
    total_minimum = GrantCalculator::EXPLORATION_SHIP_COST + GrantCalculator::MINIMUM_CREW_COST
    remaining = GrantCalculator::GRANT_AMOUNT - total_minimum

    # Should have at least 2000 credits left for fuel, repairs, initial trading
    assert remaining >= 2_000,
           "Grant should leave at least 2,000 operating capital (leaves #{remaining})"
  end

  test ".calculate returns the grant amount" do
    assert_equal GrantCalculator::GRANT_AMOUNT, GrantCalculator.calculate
  end

  test ".breakdown returns hash with ship, crew, and buffer amounts" do
    breakdown = GrantCalculator.breakdown

    assert_kind_of Hash, breakdown
    assert breakdown.key?(:ship_cost)
    assert breakdown.key?(:crew_cost)
    assert breakdown.key?(:operating_capital)
    assert breakdown.key?(:total)

    assert_equal GrantCalculator::GRANT_AMOUNT, breakdown[:total]
    assert_equal breakdown[:ship_cost] + breakdown[:crew_cost] + breakdown[:operating_capital],
                 breakdown[:total]
  end
end
