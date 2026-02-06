# frozen_string_literal: true

require "test_helper"

class BuildingBroadcastTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @system = systems(:cradle)
    @building = Building.create!(
      user: @user,
      system: @system,
      name: "Test Facility",
      race: "vex",
      function: "defense",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 1.second.ago  # Construction already complete
    )
  end

  test "building has broadcast_construction_complete method" do
    assert @building.respond_to?(:broadcast_construction_complete),
      "Building should respond to broadcast_construction_complete"
  end

  test "building has broadcast_construction_complete_target method" do
    assert @building.respond_to?(:broadcast_construction_complete_target),
      "Building should respond to broadcast_construction_complete_target"
  end

  test "broadcast_construction_complete_target returns correct stream name" do
    expected_target = "buildings_user_#{@user.id}"
    assert_equal expected_target, @building.broadcast_construction_complete_target
  end

  test "check_construction_complete! completes successfully and changes status" do
    assert_equal "under_construction", @building.status

    @building.check_construction_complete!

    assert_equal "active", @building.reload.status
    assert_nil @building.construction_ends_at
  end

  test "broadcast_construction_complete is called during check_construction_complete!" do
    broadcast_called = false
    @building.define_singleton_method(:broadcast_construction_complete) do
      broadcast_called = true
    end

    @building.check_construction_complete!

    assert broadcast_called, "broadcast_construction_complete should be called during check_construction_complete!"
  end

  test "no completion processing when building is already active" do
    active_building = Building.create!(
      user: @user,
      system: @system,
      name: "Active Building",
      race: "vex",
      function: "defense",
      tier: 1,
      status: "active"
    )

    broadcast_called = false
    active_building.define_singleton_method(:broadcast_construction_complete) do
      broadcast_called = true
    end

    active_building.check_construction_complete!

    refute broadcast_called, "broadcast_construction_complete should not be called for active buildings"
  end

  test "no completion processing when construction time is in the future" do
    future_building = Building.create!(
      user: @user,
      system: @system,
      name: "Future Building",
      race: "vex",
      function: "logistics",
      tier: 1,
      status: "under_construction",
      construction_ends_at: 1.hour.from_now
    )

    broadcast_called = false
    future_building.define_singleton_method(:broadcast_construction_complete) do
      broadcast_called = true
    end

    future_building.check_construction_complete!

    refute broadcast_called, "broadcast_construction_complete should not be called when construction is in the future"
  end

  test "building includes Turbo::Broadcastable" do
    assert Building.include?(Turbo::Broadcastable),
      "Building should include Turbo::Broadcastable"
  end
end
