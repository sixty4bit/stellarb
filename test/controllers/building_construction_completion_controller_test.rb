# frozen_string_literal: true

require "test_helper"

class BuildingConstructionCompletionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
    @building = buildings(:mining_facility)
  end

  # ===========================================
  # before_action :check_building_construction Tests
  # ===========================================

  test "buildings index automatically checks construction completion" do
    # Put building under construction with completion time in the past
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.minute.ago
    )

    # Access buildings index
    get buildings_path
    assert_response :success

    # Building should now be active
    @building.reload
    assert_equal "active", @building.status
    assert_nil @building.construction_ends_at
  end

  test "buildings show automatically checks construction completion" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.minute.ago
    )

    get building_path(@building)
    assert_response :success

    @building.reload
    assert_equal "active", @building.status
  end

  test "does not change buildings still under construction" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    get buildings_path
    assert_response :success

    # Building should still be under construction
    @building.reload
    assert_equal "under_construction", @building.status
    assert_not_nil @building.construction_ends_at
  end

  test "does not change already active buildings" do
    @building.update!(
      status: "active",
      construction_ends_at: nil
    )

    get buildings_path
    assert_response :success

    @building.reload
    assert_equal "active", @building.status
  end

  test "checks multiple buildings on index" do
    # Create a second building under construction
    building2 = Building.create!(
      name: "Second Mine",
      short_id: "bl-min2",
      user: @user,
      system: systems(:cradle),
      race: "vex",
      function: "extraction",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 1.minute.ago,
      building_attributes: { output_rate: 10 }
    )
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.minute.ago
    )

    get buildings_path
    assert_response :success

    # Both buildings should now be active
    @building.reload
    building2.reload
    assert_equal "active", @building.status
    assert_equal "active", building2.status
  end
end
