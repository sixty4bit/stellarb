# frozen_string_literal: true

require "test_helper"

class NavigationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
    @ship = ships(:hauler) # First operational ship (alphabetically) for pilot user
  end

  test "index renders navigation view" do
    get navigation_index_path
    assert_response :success
    assert_select "h2", text: /Navigation/
  end

  test "index shows current location section" do
    get navigation_index_path
    assert_response :success
    assert_select "h3", text: /Current Location/
  end

  test "index shows reachable systems section" do
    get navigation_index_path
    assert_response :success
    assert_select "h3", text: /Reachable Systems/
  end

  test "index shows ship info when available" do
    get navigation_index_path
    assert_response :success
    # Ship name should appear (Stellar Hauler is the first operational ship)
    assert_match @ship.name, response.body
  end

  test "warp without destination returns error" do
    post warp_navigation_index_path, params: { destination_id: nil }
    assert_redirected_to navigation_index_path
    follow_redirect!
    assert_select ".bg-red-800", text: /Destination system not found/
  end

  test "warp to unreachable system fails due to no warp gate" do
    # Create a far-away system (within coordinate range 0-9)
    far_system = System.create!(
      x: 9, y: 9, z: 9,
      name: "Far Away System",
      short_id: "sy-far"
    )

    post warp_navigation_index_path, params: {
      destination_id: far_system.id,
      intent: "trade"
    }

    assert_redirected_to navigation_index_path
    follow_redirect!
    # Should show an error about no warp gate (conventional travel not enough fuel)
    assert response.body.include?("Insufficient fuel") || response.body.include?("No warp gate")
  end

  test "shows travel button for reachable systems" do
    get navigation_index_path
    assert_response :success
    # Alpha Centauri is reachable, so Travel button should appear
    assert_select "input[value='Travel →']"
  end

  # In-Transit View Tests (4s1.3)
  test "shows in-transit view when ship is traveling" do
    sign_out
    traveler = users(:traveler)
    sign_in_as(traveler)

    get navigation_index_path
    assert_response :success

    # Should show in-transit panel
    assert_select "h3", text: /In Transit/
    assert_select "strong", text: "Alpha Centauri"
  end

  test "hides reachable systems when ship is in transit" do
    sign_out
    traveler = users(:traveler)
    sign_in_as(traveler)

    get navigation_index_path
    assert_response :success

    # Should NOT show reachable systems section
    assert_select "h3", text: /Reachable Systems/, count: 0
    # Should NOT show warp gates section
    assert_select "h3", text: /Warp Gates/, count: 0
  end

  test "shows ETA countdown when ship is in transit" do
    sign_out
    traveler = users(:traveler)
    sign_in_as(traveler)

    get navigation_index_path
    assert_response :success

    # Should show ETA section with countdown
    assert_select "[data-controller='countdown']"
    assert_match /ETA/, response.body
  end
end
