# frozen_string_literal: true

# Migration for SolidCache tables
# Converted from solid_cache gem's cache_schema.rb for single-database setup
class CreateSolidCacheTables < ActiveRecord::Migration[7.2]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false

      t.index :byte_size
      t.index [:key_hash, :byte_size]
      t.index :key_hash, unique: true
    end
  end
end
