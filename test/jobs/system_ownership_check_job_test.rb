# frozen_string_literal: true

require "test_helper"

class SystemOwnershipCheckJobTest < ActiveSupport::TestCase
  setup do
    @suffix = SecureRandom.hex(4)
    @owner = create_user(name: "Owner", email: "owner-#{@suffix}@test.com", credits: 1000)
    @bidder = create_user(name: "Bidder", email: "bidder-#{@suffix}@test.com", credits: 500)
  end

  # ===========================================
  # Inactivity Detection
  # ===========================================

  test "creates auction after 30 days inactivity" do
    system = create_owned_system(@owner, inactive_days: 31)

    SystemOwnershipCheckJob.perform_now

    assert system.reload.under_auction?
    auction = SystemAuction.for_system(system).active.first
    assert_not_nil auction
    assert_equal @owner, auction.previous_owner
  end

  test "does not create auction for active owners" do
    system = create_owned_system(@owner, inactive_days: 15)

    SystemOwnershipCheckJob.perform_now

    assert_not system.reload.under_auction?
    assert_equal 0, SystemAuction.for_system(system).count
  end

  test "does not create duplicate auctions" do
    system = create_owned_system(@owner, inactive_days: 31)

    SystemOwnershipCheckJob.perform_now
    SystemOwnershipCheckJob.perform_now # Run twice

    assert_equal 1, SystemAuction.for_system(system).where(status: %w[pending active]).count
  end

  # ===========================================
  # Warning Messages
  # ===========================================

  test "sends warning 5 days before seizure" do
    system = create_owned_system(@owner, inactive_days: 25) # 5 days until threshold

    SystemOwnershipCheckJob.perform_now

    message = @owner.messages.where(category: "seizure_warning").last
    assert_not_nil message, "Expected a seizure warning message"
    assert_match /5 day/i, message.body
    assert_match system.name, message.title
  end

  test "sends warning 3 days before seizure" do
    system = create_owned_system(@owner, inactive_days: 27) # 3 days until threshold

    SystemOwnershipCheckJob.perform_now

    message = @owner.messages.where(category: "seizure_warning").last
    assert_not_nil message
    assert_match /3 day/i, message.body
  end

  test "sends urgent warning 1 day before seizure" do
    system = create_owned_system(@owner, inactive_days: 29) # 1 day until threshold

    SystemOwnershipCheckJob.perform_now

    message = @owner.messages.where(category: "seizure_warning").last
    assert_not_nil message
    assert_match /1 day/i, message.body
    assert message.urgent?
  end

  test "does not send duplicate warnings within 24 hours" do
    system = create_owned_system(@owner, inactive_days: 25)

    SystemOwnershipCheckJob.perform_now
    initial_count = @owner.messages.where(category: "seizure_warning").count

    SystemOwnershipCheckJob.perform_now # Run again

    assert_equal initial_count, @owner.messages.where(category: "seizure_warning").count
  end

  # ===========================================
  # Auction Finalization
  # ===========================================

  test "finalizes ended auctions" do
    system = create_owned_system(@owner, inactive_days: 31)
    auction = SystemAuction.create_for_inactive_system!(system)
    auction.place_bid!(@bidder, 100)
    auction.update!(ends_at: 1.hour.ago)

    SystemOwnershipCheckJob.perform_now

    assert_equal "completed", auction.reload.status
    assert_equal @bidder, system.reload.owner
  end

  test "transfers ownership to highest bidder" do
    system = create_owned_system(@owner, inactive_days: 31)
    bidder2 = create_user(name: "Bidder2", email: "bidder2-#{@suffix}@test.com", credits: 1000)

    auction = SystemAuction.create_for_inactive_system!(system)
    auction.place_bid!(@bidder, 100)
    auction.place_bid!(bidder2, 200)
    auction.update!(ends_at: 1.hour.ago)

    SystemOwnershipCheckJob.perform_now

    assert_equal bidder2, system.reload.owner
  end

  test "system becomes unowned if no bids" do
    system = create_owned_system(@owner, inactive_days: 31)
    auction = SystemAuction.create_for_inactive_system!(system)
    auction.update!(ends_at: 1.hour.ago)

    SystemOwnershipCheckJob.perform_now

    assert_nil system.reload.owner
    assert_equal "completed", auction.reload.status
  end

  private

  def create_user(name:, email:, credits: 500)
    User.create!(
      name: name,
      email: email,
      short_id: "us-#{SecureRandom.hex(3)}",
      credits: credits
    )
  end

  def create_owned_system(owner, inactive_days:)
    # Use valid coordinates (must be in 0-9 range and divisible by 3)
    coords = [[0, 3, 6], [3, 6, 9], [6, 9, 3], [9, 3, 6], [3, 9, 0]].sample
    System.create!(
      name: "System-#{SecureRandom.hex(4)}",
      x: coords[0],
      y: coords[1],
      z: coords[2],
      short_id: "sy-#{SecureRandom.hex(3)}",
      owner: owner,
      owner_last_visit_at: inactive_days.days.ago,
      properties: { "star_type" => "yellow_dwarf" }
    )
  end
end
