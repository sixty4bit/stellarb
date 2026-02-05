# frozen_string_literal: true

require "application_system_test_case"

class NavigationInTransitTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    # Ensure user has completed onboarding so modals don't block tests
    @user.update!(
      profile_completed_at: 1.day.ago,
      onboarding_completed_at: 1.day.ago
    )

    @origin = systems(:cradle)
    @destination = systems(:alpha_centauri)

    @ship = Ship.create!(
      name: "Transit Tester",
      user: @user,
      race: "vex",
      hull_size: "scout",
      variant_idx: 1,
      fuel: 50,
      status: "docked",
      current_system: @origin
    )

    # Sign in
    visit new_session_path
    fill_in "user_email", with: @user.email
    click_button "[ TRANSMIT ACCESS REQUEST ]"
  end

  test "docked ship shows reachable systems" do
    click_on "Navigation"

    assert_text "Reachable Systems"
    assert_no_text "En route to"
  end

  test "in-transit ship shows destination and ETA" do
    # Put ship in transit
    @ship.update!(
      status: "in_transit",
      destination_system: @destination,
      arrival_at: 30.minutes.from_now
    )

    click_on "Navigation"

    assert_text "En route to"
    assert_text @destination.name
    assert_text "ETA"
    # Should hide reachable systems section
    assert_no_text "🚀 Reachable Systems"
  end

  test "in-transit ship hides travel controls" do
    @ship.update!(
      status: "in_transit",
      destination_system: @destination,
      arrival_at: 30.minutes.from_now
    )

    click_on "Navigation"

    # Should not show "Travel →" buttons
    assert_no_button "Travel →"
    assert_no_button "Warp →"
  end

  test "current location still visible when in transit" do
    @ship.update!(
      status: "in_transit",
      destination_system: @destination,
      arrival_at: 30.minutes.from_now,
      location_x: @origin.x,
      location_y: @origin.y,
      location_z: @origin.z
    )

    click_on "Navigation"

    assert_text "Current Location"
  end
end
