# Bot Simulation Helper
#
# Provides methods for automated bot testing of game mechanics.
# Used in system tests to simulate player actions and verify game state.
#
module BotSimulationHelper
  # ===================
  # User Management
  # ===================

  # Create a new user with default starting conditions
  def create_bot_user(email: "bot_#{SecureRandom.hex(4)}@test.com", credits: 500)
    user = User.create!(
      email_address: email,
      credits: credits
    )
    user
  end

  # Sign in as a user (for system tests)
  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    click_button "Sign in"
  end

  # ===================
  # Ship Operations
  # ===================

  # Purchase a ship for a user
  def bot_purchase_ship(user, ship_type: :scout, name: "BotShip-#{SecureRandom.hex(3)}")
    ship = Ship.create!(
      user: user,
      name: name,
      ship_type: ship_type,
      hull_size: :scout,
      race: :vex,
      cargo_capacity: 50,
      fuel_capacity: 100,
      fuel_current: 100,
      hull_points: 100,
      hull_points_max: 100,
      status: :docked,
      current_system: user.current_system
    )
    ship
  end

  # Navigate a ship to a target system
  def bot_navigate_ship(ship, target_system)
    ship.update!(
      status: :traveling,
      destination_system: target_system
    )

    # Simulate travel completion for testing
    ship.update!(
      status: :docked,
      current_system: target_system,
      destination_system: nil
    )
  end

  # ===================
  # Trading Operations
  # ===================

  # Buy a commodity at current market prices
  def bot_buy_commodity(user, ship, commodity:, quantity:)
    system = ship.current_system
    price = system.market_price_for(commodity)
    total_cost = price * quantity

    return false if user.credits < total_cost
    return false if ship.cargo_space_remaining < quantity

    user.update!(credits: user.credits - total_cost)
    ship.add_cargo(commodity, quantity)
    true
  end

  # Sell a commodity at current market prices
  def bot_sell_commodity(user, ship, commodity:, quantity:)
    system = ship.current_system
    price = system.market_price_for(commodity)
    total_revenue = price * quantity

    return false unless ship.has_cargo?(commodity, quantity)

    ship.remove_cargo(commodity, quantity)
    user.update!(credits: user.credits + total_revenue)
    true
  end

  # Execute a complete trading loop: buy at A, travel to B, sell
  def bot_execute_trade_loop(user, ship, buy_system:, sell_system:, commodity:, quantity:)
    # Travel to buy system if not already there
    bot_navigate_ship(ship, buy_system) unless ship.current_system == buy_system

    # Buy commodity
    return { success: false, reason: "buy_failed" } unless bot_buy_commodity(user, ship, commodity: commodity, quantity: quantity)

    credits_after_buy = user.credits

    # Travel to sell system
    bot_navigate_ship(ship, sell_system)

    # Sell commodity
    return { success: false, reason: "sell_failed" } unless bot_sell_commodity(user, ship, commodity: commodity, quantity: quantity)

    profit = user.credits - credits_after_buy

    { success: true, profit: profit }
  end

  # ===================
  # System/Navigation
  # ===================

  # Get or create a test system at specific coordinates
  def get_or_create_system(x:, y:, z:, name: nil)
    system = System.find_by(x: x, y: y, z: z)
    return system if system

    System.realize!(x, y, z)
  end

  # Get The Cradle (0,0,0)
  def the_cradle
    get_or_create_system(x: 0, y: 0, z: 0)
  end

  # ===================
  # Worker Management
  # ===================

  # Hire a recruit for a user
  def bot_hire_recruit(user, recruit)
    hired = HiredRecruit.create_from_recruit!(recruit)
    Hiring.create!(
      user: user,
      hired_recruit: hired,
      wage: hired.calculate_wage,
      status: :active
    )
    hired
  end

  # Assign a worker to a ship
  def bot_assign_worker_to_ship(hiring, ship)
    hiring.update!(assignable: ship)
  end

  # ===================
  # Building Operations
  # ===================

  # Construct a building in a system
  def bot_construct_building(user, system, building_type:)
    building = Building.create!(
      user: user,
      system: system,
      building_type: building_type,
      status: :constructing
    )

    # For testing, complete construction immediately
    building.update!(status: :operational)
    building
  end

  # ===================
  # Assertions
  # ===================

  # Assert user has minimum credits
  def assert_user_credits_at_least(user, minimum)
    user.reload
    assert user.credits >= minimum, "Expected user to have at least #{minimum} credits, but has #{user.credits}"
  end

  # Assert user owns a ship
  def assert_user_owns_ship(user, ship)
    assert user.ships.include?(ship), "Expected user to own ship #{ship.name}"
  end

  # Assert ship is in a specific system
  def assert_ship_in_system(ship, system)
    ship.reload
    assert_equal system.id, ship.current_system_id, "Expected ship to be in #{system.name}"
  end

  # Assert ship has cargo
  def assert_ship_has_cargo(ship, commodity, quantity)
    ship.reload
    actual = ship.cargo_quantity(commodity)
    assert actual >= quantity, "Expected ship to have #{quantity} #{commodity}, but has #{actual}"
  end

  # Assert a trade was profitable
  def assert_profitable_trade(initial_credits, final_credits)
    assert final_credits > initial_credits,
      "Expected profitable trade. Initial: #{initial_credits}, Final: #{final_credits}"
  end

  # ===================
  # Test Data Setup
  # ===================

  # Set up a complete trading scenario with two systems and price difference
  def setup_trading_scenario
    # Create two systems with different prices
    buy_system = get_or_create_system(x: 1, y: 0, z: 0, name: "CheapTown")
    sell_system = get_or_create_system(x: 2, y: 0, z: 0, name: "RichCity")

    # Set up price deltas so there's an arbitrage opportunity
    # Buy system has cheap goods, sell system pays more
    PriceDelta.find_or_create_by!(system: buy_system, commodity: "iron") do |pd|
      pd.delta = -50  # 50 credits cheaper than base
    end

    PriceDelta.find_or_create_by!(system: sell_system, commodity: "iron") do |pd|
      pd.delta = 50  # 50 credits more expensive than base
    end

    { buy_system: buy_system, sell_system: sell_system, commodity: "iron" }
  end

  # Set up a complete onboarding scenario
  def setup_onboarding_scenario
    # Ensure The Cradle exists
    cradle = the_cradle

    # Create starter quests if needed
    Quest.find_or_create_by!(identifier: "phase1_supply_chain") do |q|
      q.name = "The Coffee Run"
      q.description = "Establish a basic supply chain"
      q.phase = 1
      q.reward_credits = 10_000
    end

    { cradle: cradle }
  end
end
