require "test_helper"

class ShipsNewViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @system = System.cradle
    sign_in_as @user
  end

  test "new ship page shows Myrmidon Scout recommendation for users without ships" do
    # Ensure user has no ships
    @user.ships.destroy_all
    assert @user.ships.reload.empty?, "User should have no ships"
    
    get new_ship_path
    
    assert_response :success
    # Check that the recommendation content exists
    assert_match /Myrmidon Scout/, response.body, "Should mention Myrmidon Scout"
    assert_match /Cheapest option/, response.body, "Should mention cost advantage"
  end

  test "new ship page does not show recommendation for users with ships" do
    # Ensure user has a ship
    Ship.create!(
      name: "Existing Ship",
      user: @user,
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system
    )
    
    get new_ship_path
    
    assert_response :success
    assert_select "[data-testid='tutorial-recommendation']", count: 0
  end

  test "Myrmidon Scout is cheapest ship option" do
    myrmidon_scout_cost = Ship.cost_for(hull_size: "scout", race: "myrmidon")
    
    Ship::RACES.each do |race|
      Ship::HULL_SIZES.each do |hull_size|
        cost = Ship.cost_for(hull_size: hull_size, race: race)
        assert cost >= myrmidon_scout_cost, 
          "#{race} #{hull_size} (#{cost}) should not be cheaper than Myrmidon Scout (#{myrmidon_scout_cost})"
      end
    end
  end
end
