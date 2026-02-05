# frozen_string_literal: true

class AddUuidToAllModels < ActiveRecord::Migration[8.1]
  def change
    # Add UUID column to all models that need the Triple-ID system
    add_column :users, :uuid, :string, limit: 36
    add_column :ships, :uuid, :string, limit: 36
    add_column :buildings, :uuid, :string, limit: 36
    add_column :systems, :uuid, :string, limit: 36
    add_column :routes, :uuid, :string, limit: 36
    add_column :recruits, :uuid, :string, limit: 36
    add_column :hired_recruits, :uuid, :string, limit: 36
    add_column :hirings, :uuid, :string, limit: 36

    # Add unique indexes
    add_index :users, :uuid, unique: true
    add_index :ships, :uuid, unique: true
    add_index :buildings, :uuid, unique: true
    add_index :systems, :uuid, unique: true
    add_index :routes, :uuid, unique: true
    add_index :recruits, :uuid, unique: true
    add_index :hired_recruits, :uuid, unique: true
    add_index :hirings, :uuid, unique: true
  end
end
