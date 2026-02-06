class CreateSystemAuctions < ActiveRecord::Migration[8.1]
  def change
    create_table :system_auctions do |t|
      t.references :system, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :ends_at
      t.references :previous_owner, foreign_key: { to_table: :users }
      t.bigint :winning_bid_id
      t.string :uuid, limit: 36

      t.timestamps
    end

    add_index :system_auctions, :status
    add_index :system_auctions, :ends_at, where: "status = 'active'"
    add_index :system_auctions, :uuid, unique: true
    add_index :system_auctions, :winning_bid_id
  end
end
