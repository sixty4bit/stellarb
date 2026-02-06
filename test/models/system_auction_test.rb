# frozen_string_literal: true

require "test_helper"

class SystemAuctionTest < ActiveSupport::TestCase
  setup do
    @suffix = SecureRandom.hex(4)
    @owner = create_user(name: "Owner", email: "owner-#{@suffix}@test.com", credits: 1000)
    @bidder1 = create_user(name: "Bidder1", email: "bidder1-#{@suffix}@test.com", credits: 500)
    @bidder2 = create_user(name: "Bidder2", email: "bidder2-#{@suffix}@test.com", credits: 500)

    @system = System.create!(
      name: "Test System",
      x: 3, y: 6, z: 9,
      short_id: "sy-test-#{@suffix}",
      owner: @owner,
      owner_last_visit_at: 31.days.ago,
      properties: { "star_type" => "yellow_dwarf" }
    )
  end

  # ===========================================
  # Auction Creation
  # ===========================================

  test "creates auction for inactive system" do
    auction = SystemAuction.create_for_inactive_system!(@system)

    assert_equal "active", auction.status
    assert_equal @owner, auction.previous_owner
    assert_equal @system, auction.system
    assert_not_nil auction.started_at
    assert_not_nil auction.ends_at
    assert_equal 48.hours.to_i, (auction.ends_at - auction.started_at).to_i
  end

  test "does not create duplicate auctions for same system" do
    SystemAuction.create_for_inactive_system!(@system)
    result = SystemAuction.create_for_inactive_system!(@system)

    assert_nil result
    assert_equal 1, SystemAuction.for_system(@system).count
  end

  # ===========================================
  # Bidding
  # ===========================================

  test "can place a bid on active auction" do
    auction = SystemAuction.create_for_inactive_system!(@system)

    auction.place_bid!(@bidder1, 100)

    assert_equal 1, auction.bids.count
    assert_equal 100, auction.current_bid
    assert_equal 400, @bidder1.reload.credits # 500 - 100 escrowed
  end

  test "minimum first bid is enforced" do
    auction = SystemAuction.create_for_inactive_system!(@system)

    error = assert_raises(RuntimeError) do
      auction.place_bid!(@bidder1, 50) # Below minimum of 100
    end

    assert_match /bid too low/i, error.message
  end

  test "minimum increment is enforced" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)

    error = assert_raises(RuntimeError) do
      auction.place_bid!(@bidder2, 105) # Must be at least 110 (100 + 10)
    end

    assert_match /bid too low/i, error.message
  end

  test "outbid refunds previous bidder" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)

    assert_equal 400, @bidder1.reload.credits

    auction.place_bid!(@bidder2, 150)

    assert_equal 500, @bidder1.reload.credits # Refunded
    assert_equal 350, @bidder2.reload.credits # 500 - 150 escrowed
  end

  test "user can update their own bid" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)

    assert_equal 400, @bidder1.reload.credits

    auction.place_bid!(@bidder1, 200) # Increasing own bid

    assert_equal 300, @bidder1.reload.credits # Net: 500 - 200
    assert_equal 1, auction.bids.count # Still only one bid from this user
  end

  test "cannot bid on your own system" do
    auction = SystemAuction.create_for_inactive_system!(@system)

    error = assert_raises(RuntimeError) do
      auction.place_bid!(@owner, 100)
    end

    assert_match /cannot bid on your own/i, error.message
  end

  test "cannot bid with insufficient credits" do
    auction = SystemAuction.create_for_inactive_system!(@system)

    error = assert_raises(RuntimeError) do
      auction.place_bid!(@bidder1, 1000) # Only has 500
    end

    assert_match /insufficient credits/i, error.message
  end

  # ===========================================
  # Auction Completion
  # ===========================================

  test "highest bidder wins at auction end" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)
    auction.place_bid!(@bidder2, 150)

    # Fast-forward time
    auction.update!(ends_at: 1.hour.ago)

    auction.complete!

    assert_equal "completed", auction.status
    assert_equal @bidder2, @system.reload.owner
    assert_equal auction.bids.find_by(user: @bidder2), auction.winning_bid
  end

  test "all bid amounts are burned on completion (money sink)" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)
    auction.place_bid!(@bidder2, 150)

    # Outbid user is immediately refunded, only highest bid escrowed
    assert_equal 500, @bidder1.reload.credits # Refunded when outbid
    assert_equal 350, @bidder2.reload.credits # Highest bid escrowed

    auction.update!(ends_at: 1.hour.ago)
    auction.complete!

    # Winner's credits stay burned (not refunded)
    assert_equal 500, @bidder1.reload.credits # Already refunded
    assert_equal 350, @bidder2.reload.credits # Winner's credits stay gone (burned)
  end

  test "system becomes unowned if no bids" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.update!(ends_at: 1.hour.ago)

    auction.complete!

    assert_equal "completed", auction.status
    assert_nil @system.reload.owner
    assert_nil auction.winning_bid
  end

  test "winner receives notification message" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)
    auction.update!(ends_at: 1.hour.ago)

    auction.complete!

    message = @bidder1.messages.where(category: "auction").last
    assert_not_nil message
    assert_match /auction won/i, message.title
    assert_match @system.name, message.body
  end

  test "previous owner receives notification when system sold" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)
    auction.update!(ends_at: 1.hour.ago)

    auction.complete!

    message = @owner.messages.where(category: "auction").last
    assert_not_nil message
    assert_match /seized/i, message.title
    assert_match @system.name, message.body
  end

  # ===========================================
  # Owner Reclaim
  # ===========================================

  test "owner visiting cancels auction and refunds bids" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)
    auction.place_bid!(@bidder2, 150)

    assert_equal 350, @bidder2.reload.credits

    auction.cancel!(reason: "owner_reclaimed")

    assert_equal "cancelled", auction.status
    assert_equal 500, @bidder2.reload.credits # Refunded
  end

  test "system visit by owner cancels active auction" do
    auction = SystemAuction.create_for_inactive_system!(@system)
    auction.place_bid!(@bidder1, 100)

    @system.record_owner_visit!(@owner)

    assert_equal "cancelled", auction.reload.status
    assert_not_nil @system.reload.owner_last_visit_at
    assert @system.owner_last_visit_at > 1.minute.ago
  end

  test "non-owner visit does not cancel auction" do
    auction = SystemAuction.create_for_inactive_system!(@system)

    @system.record_owner_visit!(@bidder1) # Not the owner

    assert_equal "active", auction.reload.status
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
end
