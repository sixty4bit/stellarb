# frozen_string_literal: true

# Calculates The Grant reward for completing Phase 1 (The Cradle)
# Per ROADMAP Section 3.4: The Grant is 10,000 credits
# Must be sufficient for exploration ship purchase + crew hiring + operating capital
class GrantCalculator
  # The total grant amount awarded for Phase 1 completion
  # Source: ROADMAP.md Section 3.4 "Phase 1 | First profitable automated route | 'The Grant' (10,000 credits)"
  GRANT_AMOUNT = 10_000

  # Cost breakdown for required purchases:

  # Scout ship (cheapest hull for exploration)
  # Based on ship base cost calculations - scout is entry-level exploration vessel
  EXPLORATION_SHIP_COST = 4_000

  # Minimum crew cost: 2 crew members (navigator + engineer minimum for scout)
  # Based on hiring costs in the Recruiter system (avg 500-1000 per crew + wages)
  MINIMUM_CREW_COST = 2_000

  # Remaining: Operating capital for fuel, initial trades, repairs
  OPERATING_CAPITAL = GRANT_AMOUNT - EXPLORATION_SHIP_COST - MINIMUM_CREW_COST

  class << self
    # Calculate the grant amount
    # @return [Integer] The grant amount in credits
    def calculate
      GRANT_AMOUNT
    end

    # Return a detailed breakdown of how the grant should be spent
    # @return [Hash] Breakdown with :ship_cost, :crew_cost, :operating_capital, :total
    def breakdown
      {
        ship_cost: EXPLORATION_SHIP_COST,
        crew_cost: MINIMUM_CREW_COST,
        operating_capital: OPERATING_CAPITAL,
        total: GRANT_AMOUNT
      }
    end
  end
end
