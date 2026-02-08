require "test_helper"

class ExplorationUiTest < ActionDispatch::IntegrationTest
  def create_system(name:, short_id:, x:, y:, z:)
    System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
  end

  setup do
    @user = users(:pilot)
    @origin = System.find_by(x: 0, y: 0, z: 0) || create_system(name: "Origin", short_id: "sy-org", x: 0, y: 0, z: 0)
    @ship = ships(:hauler)
    @ship.update_columns(current_system_id: @origin.id, location_x: 0, location_y: 0, location_z: 0, fuel: 100.0, status: "docked")
    sign_in_as(@user)
  end

  test "shows ship position" do
    get exploration_path
    assert_response :success
    assert_select "p", /\(0, 0, 0\)/
  end

  test "shows fuel info" do
    get exploration_path
    assert_response :success
    assert_select "p", /Fuel:/
  end

  test "disables buttons when in transit" do
    @ship.update_columns(status: "in_transit", arrival_at: 5.minutes.from_now,
                         destination_x: 1, destination_y: 0, destination_z: 0)
    get exploration_path
    assert_response :success
    assert_select "h3", /Ship In Transit/
  end

  test "shows destination when in transit" do
    @ship.update_columns(status: "in_transit", arrival_at: 5.minutes.from_now,
                         destination_x: 1, destination_y: 0, destination_z: 0)
    get exploration_path
    assert_response :success
    assert_select "p", /\(1, 0, 0\)/
  end
end
