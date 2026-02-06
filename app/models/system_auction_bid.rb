# frozen_string_literal: true

# Individual bid on a system auction
class SystemAuctionBid < ApplicationRecord
  # Associations
  belongs_to :auction, class_name: "SystemAuction"
  belongs_to :user

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :placed_at, presence: true
  validates :uuid, uniqueness: true, allow_nil: true
  validates :user_id, uniqueness: {
    scope: :auction_id,
    message: "can only have one active bid per auction"
  }

  # Callbacks
  before_create :generate_uuid

  # Scopes
  scope :by_amount, -> { order(amount: :desc) }

  # Check if this is the winning bid
  def winning?
    auction.winning_bid_id == id
  end

  # Check if this is currently the highest bid
  def highest?
    auction.highest_bid == self
  end

  # Refund this bid to the user
  def refund!
    return if refunded?

    user.update!(credits: user.credits + amount)
    @refunded = true
  end

  def refunded?
    @refunded || false
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
