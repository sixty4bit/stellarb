# frozen_string_literal: true

require "test_helper"

class SystemAuctionBidTest < ActiveSupport::TestCase
  setup do
    @suffix = SecureRandom.hex(4)
    @owner = create_user(name: "Owner", email: "owner-#{@suffix}@test.com", credits: 1000)
    @bidder = create_user(name: "Bidder", email: "bidder-#{@suffix}@test.com", credits: 500)

    @system = System.create!(
      name: "Test System",
      x: 3, y: 6, z: 9,
      short_id: "sy-bid-#{@suffix}",
      owner: @owner,
      owner_last_visit_at: 31.days.ago,
      properties: { "star_type" => "yellow_dwarf" }
    )

    @auction = SystemAuction.create_for_inactive_system!(@system)
  end

  test "creates bid with valid attributes" do
    bid = SystemAuctionBid.create!(
      auction: @auction,
      user: @bidder,
      amount: 100,
      placed_at: Time.current
    )

    assert bid.persisted?
    assert_not_nil bid.uuid
  end

  test "validates amount is positive" do
    bid = SystemAuctionBid.new(
      auction: @auction,
      user: @bidder,
      amount: -50,
      placed_at: Time.current
    )

    assert_not bid.valid?
    assert_includes bid.errors[:amount], "must be greater than 0"
  end

  test "validates placed_at is present" do
    bid = SystemAuctionBid.new(
      auction: @auction,
      user: @bidder,
      amount: 100
    )

    assert_not bid.valid?
    assert_includes bid.errors[:placed_at], "can't be blank"
  end

  test "validates one bid per user per auction" do
    SystemAuctionBid.create!(
      auction: @auction,
      user: @bidder,
      amount: 100,
      placed_at: Time.current
    )

    duplicate = SystemAuctionBid.new(
      auction: @auction,
      user: @bidder,
      amount: 150,
      placed_at: Time.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "can only have one active bid per auction"
  end

  test "refund! adds credits back to user" do
    original_credits = @bidder.credits

    bid = SystemAuctionBid.create!(
      auction: @auction,
      user: @bidder,
      amount: 100,
      placed_at: Time.current
    )

    # Simulate escrowing
    @bidder.update!(credits: original_credits - 100)
    assert_equal 400, @bidder.reload.credits

    bid.refund!

    assert_equal 500, @bidder.reload.credits
    assert bid.refunded?
  end

  test "refund! is idempotent" do
    bid = SystemAuctionBid.create!(
      auction: @auction,
      user: @bidder,
      amount: 100,
      placed_at: Time.current
    )

    @bidder.update!(credits: 400)

    bid.refund!
    bid.refund! # Should not double-refund

    assert_equal 500, @bidder.reload.credits
  end

  test "highest? returns true for top bid" do
    bid1 = @auction.bids.create!(user: @bidder, amount: 100, placed_at: Time.current)

    assert bid1.highest?
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
