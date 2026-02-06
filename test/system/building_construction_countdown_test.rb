# frozen_string_literal: true

require "application_system_test_case"

class BuildingConstructionCountdownTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(
      profile_completed_at: 1.day.ago,
      onboarding_completed_at: 1.day.ago
    )

    @system = systems(:cradle)

    # Sign in
    visit new_session_path
    fill_in "user_email", with: @user.email
    click_button "[ TRANSMIT ACCESS REQUEST ]"
  end

  test "building index shows countdown for buildings under construction" do
    building = Building.create!(
      user: @user,
      system: @system,
      name: "Test Extractor",
      race: "krog",
      function: "defense",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 30.seconds.from_now
    )

    click_on "Buildings"

    # Should show construction status
    assert_text "UNDER CONSTRUCTION"
    
    # Should have countdown element
    countdown_element = find("[data-controller='countdown']")
    assert countdown_element.present?
    
    # Should display time format
    assert_match(/\d+[hms]/, countdown_element.text)
  end

  test "building show page displays countdown for building under construction" do
    building = Building.create!(
      user: @user,
      system: @system,
      name: "Test Warehouse",
      race: "vex",
      function: "logistics",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 30.seconds.from_now
    )

    # Navigate through UI (Turbo Frame navigation)
    click_on "Buildings"
    click_on "Test Warehouse"

    # Should show construction in progress message
    assert_text "Construction in Progress"
    
    # Should have countdown element
    countdown_element = find("[data-controller='countdown']")
    assert countdown_element.present?
    
    # Should display time format
    assert_match(/\d+[hms]/, countdown_element.text)
  end

  test "building countdown auto-refreshes when construction completes" do
    building = Building.create!(
      user: @user,
      system: @system,
      name: "Quick Build",
      race: "krog",
      function: "defense",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 2.seconds.from_now
    )

    # Navigate through UI
    click_on "Buildings"
    click_on "Quick Build"

    # Initially should show construction in progress
    assert_text "Construction in Progress"

    # Complete the construction in the database (simulating time passing)
    sleep 3
    building.check_construction_complete!

    # After countdown completes, page should auto-refresh and show operational status
    # The countdown controller reloads the frame after reaching zero
    sleep 3  # 2s countdown + 1s delay + buffer

    # After refresh, should show operational status
    assert_text "OPERATIONAL"
    assert_no_text "Construction in Progress"
  end
end
