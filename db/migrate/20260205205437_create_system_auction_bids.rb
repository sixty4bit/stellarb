class CreateSystemAuctionBids < ActiveRecord::Migration[8.1]
  def change
    create_table :system_auction_bids do |t|
      t.references :auction, null: false, foreign_key: { to_table: :system_auctions }
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.datetime :placed_at, null: false
      t.string :uuid, limit: 36

      t.timestamps
    end

    add_index :system_auction_bids, [:auction_id, :amount], order: { amount: :desc }
    add_index :system_auction_bids, :uuid, unique: true
  end
end
