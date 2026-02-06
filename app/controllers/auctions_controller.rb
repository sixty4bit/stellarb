# frozen_string_literal: true

class AuctionsController < ApplicationController
  before_action :require_login
  before_action :set_auction, only: [:show, :bid]

  # GET /auctions
  # List all active auctions
  def index
    @auctions = SystemAuction.active.includes(:system, :bids).order(ends_at: :asc)
  end

  # GET /auctions/:id
  # Show auction details
  def show
    @bids = @auction.bids.by_amount.limit(10)
    @minimum_bid = @auction.minimum_bid
    @user_bid = @auction.bids.find_by(user: Current.user)
  end

  # POST /auctions/:id/bid
  # Place a bid on an auction
  def bid
    amount = params[:amount].to_d

    @auction.place_bid!(Current.user, amount)

    respond_to do |format|
      format.html { redirect_to auction_path(@auction), notice: "Bid placed successfully!" }
      format.turbo_stream
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to auction_path(@auction), alert: e.message }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("bid_form", partial: "bid_form", locals: { auction: @auction, error: e.message }) }
    end
  end

  private

  def set_auction
    @auction = SystemAuction.find(params[:id])
  end
end
