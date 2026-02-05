# frozen_string_literal: true

require "test_helper"

class BuildingConstructionCompletionTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @system = systems(:cradle)
    @building = buildings(:mining_facility)
  end

  # ===========================================
  # check_construction_complete! Tests
  # ===========================================

  test "check_construction_complete! activates building when construction is complete" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.minute.ago
    )

    @building.check_construction_complete!

    @building.reload
    assert_equal "active", @building.status
    assert_nil @building.construction_ends_at
  end

  test "check_construction_complete! does nothing when construction is not yet complete" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    @building.check_construction_complete!

    @building.reload
    assert_equal "under_construction", @building.status
    assert_not_nil @building.construction_ends_at
  end

  test "check_construction_complete! does nothing for already active buildings" do
    @building.update!(
      status: "active",
      construction_ends_at: nil
    )

    @building.check_construction_complete!

    @building.reload
    assert_equal "active", @building.status
  end

  test "check_construction_complete! does nothing when construction_ends_at is nil" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: nil
    )

    @building.check_construction_complete!

    @building.reload
    assert_equal "under_construction", @building.status
  end

  # ===========================================
  # Scope Tests
  # ===========================================

  test "under_construction scope returns buildings being built" do
    @building.update!(status: "under_construction")

    assert_includes Building.under_construction, @building
  end

  test "under_construction scope excludes active buildings" do
    @building.update!(status: "active")

    refute_includes Building.under_construction, @building
  end

  test "construction_complete scope returns buildings ready to activate" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.minute.ago
    )

    assert_includes Building.construction_complete, @building
  end

  test "construction_complete scope excludes buildings still building" do
    @building.update!(
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    refute_includes Building.construction_complete, @building
  end
end
