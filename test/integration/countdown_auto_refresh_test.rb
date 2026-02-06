# frozen_string_literal: true

require "test_helper"

class CountdownAutoRefreshTest < ActionDispatch::IntegrationTest
  # Test that countdowns have correct data attributes for auto-refresh

  test "ship arrival countdown has correct frame target" do
    # Use traveler who has a ship in transit
    sign_in_as(users(:traveler))

    get navigation_index_path
    assert_response :success

    # Verify countdown has both arrival value and frame target
    assert_select "[data-controller='countdown']" do |elements|
      countdown = elements.first
      assert countdown["data-countdown-arrival-value"].present?,
        "Expected countdown to have arrival value"
      assert_equal "content_panel", countdown["data-countdown-frame-value"],
        "Expected countdown frame target to be 'content_panel'"
    end
  end

  test "building construction countdown has correct frame target on index" do
    user = users(:pilot)
    sign_in_as(user)

    # Create a building under construction
    building = Building.create!(
      user: user,
      system: systems(:cradle),
      name: "Test Construction Site",
      function: "extraction",
      race: "vex",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    get buildings_path
    assert_response :success

    # Verify countdown has correct frame target
    assert_select "[data-controller='countdown'][data-countdown-frame-value='content_panel']" do |elements|
      assert elements.any? { |e| e["data-countdown-arrival-value"].present? },
        "Expected at least one countdown with arrival value"
    end

    building.destroy
  end

  test "building construction countdown has correct frame target on show" do
    user = users(:pilot)
    sign_in_as(user)

    # Create a building under construction
    building = Building.create!(
      user: user,
      system: systems(:cradle),
      name: "Test Construction Site",
      function: "extraction",
      race: "vex",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    get building_path(building)
    assert_response :success

    # Verify countdown has correct frame target
    assert_select "[data-controller='countdown'][data-countdown-frame-value='content_panel']"

    building.destroy
  end

  test "recruiter pool refresh countdown has correct frame target" do
    user = users(:pilot)
    sign_in_as(user)

    # Use existing fixture recruit which has expires_at set
    recruit = recruits(:engineer_bob)

    get recruiters_path
    assert_response :success

    # Verify countdown has correct frame target for pool refresh
    assert_select "[data-controller='countdown'][data-countdown-frame-value='content_panel']"
  end

  test "workers recruiter page has countdown with correct frame target" do
    user = users(:pilot)
    sign_in_as(user)

    # Use existing fixture recruit which has expires_at set
    recruit = recruits(:navigator_zara)

    get recruiter_workers_path
    assert_response :success

    # Verify countdown has correct frame target
    assert_select "[data-controller='countdown'][data-countdown-frame-value='content_panel']"
  end
end
