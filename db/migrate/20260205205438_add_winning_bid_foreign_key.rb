class AddWinningBidForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :system_auctions, :system_auction_bids, column: :winning_bid_id
  end
end
