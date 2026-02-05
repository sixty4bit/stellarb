# frozen_string_literal: true

require "test_helper"

class BuildingCheckConstructionTest < ActiveSupport::TestCase
  setup do
    @building = buildings(:mining_facility)
  end

  # check_construction_complete! tests
  test "check_construction_complete! transitions under_construction to active when complete" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.minute.ago
    )

    @building.check_construction_complete!

    assert_equal "active", @building.status
    assert_nil @building.construction_ends_at
  end

  test "check_construction_complete! does nothing when construction is not finished" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    @building.check_construction_complete!

    assert_equal "under_construction", @building.status
    assert_not_nil @building.construction_ends_at
  end

  test "check_construction_complete! does nothing for active buildings" do
    @building.update!(
      status: "active",
      construction_ends_at: nil
    )

    @building.check_construction_complete!

    assert_equal "active", @building.status
  end

  test "check_construction_complete! does nothing for inactive buildings" do
    @building.update!(
      status: "inactive",
      construction_ends_at: nil
    )

    @building.check_construction_complete!

    assert_equal "inactive", @building.status
  end

  test "check_construction_complete! does nothing for destroyed buildings" do
    @building.update!(
      status: "destroyed",
      construction_ends_at: nil
    )

    @building.check_construction_complete!

    assert_equal "destroyed", @building.status
  end

  # Scope tests
  test "under_construction scope returns buildings with under_construction status" do
    @building.update!(status: "under_construction", construction_ends_at: 1.hour.from_now)
    
    assert_includes Building.under_construction, @building
  end

  test "under_construction scope excludes active buildings" do
    @building.update!(status: "active")
    
    refute_includes Building.under_construction, @building
  end
end
