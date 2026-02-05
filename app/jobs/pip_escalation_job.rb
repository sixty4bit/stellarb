# frozen_string_literal: true

# Daily job that escalates unresolved pip infestations and spreads them to adjacent assets.
# Implements the "Pip Escalation" mechanic from ROADMAP Section 15.
#
# Escalation behavior:
# - Unresolved pip infestations spread to adjacent assets in the same system
# - ~10% chance per adjacent asset per day
# - Pips cannot spread to already-infested assets
class PipEscalationJob < ApplicationJob
  queue_as :default

  # Chance per adjacent asset per day to spread
  SPREAD_CHANCE = 0.10

  class << self
    # Check if a pip should spread to an adjacent asset
    def should_spread?
      rand < SPREAD_CHANCE
    end
  end

  def perform
    results = {
      incidents_processed: 0,
      spread_count: 0
    }

    # Process all unresolved pip infestations
    Incident.pip_infestations.unresolved.find_each do |incident|
      results[:incidents_processed] += 1

      # Try to spread to adjacent assets
      spread_count = spread_infection(incident)
      results[:spread_count] += spread_count
    end

    results
  end

  private

  # Spread the pip infection to adjacent assets
  def spread_infection(incident)
    spread_count = 0
    asset = incident.asset
    system = get_system_for_asset(asset)

    return 0 unless system

    # Find adjacent assets in the same system
    adjacent_assets = find_adjacent_assets(asset, system)

    adjacent_assets.each do |adjacent|
      next unless self.class.should_spread?
      next if has_active_pip_infestation?(adjacent)

      create_spread_infestation(adjacent)
      spread_count += 1
    end

    spread_count
  end

  # Get the system for an asset
  def get_system_for_asset(asset)
    if asset.respond_to?(:current_system)
      asset.current_system # Ships
    elsif asset.respond_to?(:system)
      asset.system # Buildings
    end
  end

  # Find adjacent assets in the same system
  def find_adjacent_assets(source_asset, system)
    adjacent = []

    # Find ships in the same system
    Ship.operational.where(current_system: system).find_each do |ship|
      adjacent << ship unless ship == source_asset
    end

    # Find buildings in the same system
    Building.operational.where(system: system).find_each do |building|
      adjacent << building unless building == source_asset
    end

    adjacent
  end

  # Check if asset already has an active pip infestation
  def has_active_pip_infestation?(asset)
    Incident.pip_infestations.unresolved.exists?(asset: asset)
  end

  # Create a new pip infestation from spreading
  def create_spread_infestation(asset)
    description = generate_spread_description

    Incident.create!(
      asset: asset,
      severity: 5, # Spread infestations are always T5
      description: description,
      is_pip_infestation: true
    )
  end

  # Generate description for spread pip infestation
  def generate_spread_description
    spread_reasons = [
      "migrated through the ventilation system",
      "hitched a ride on a cargo container",
      "tunneled through the hull",
      "were delivered via 'totally legitimate' supply crate",
      "evolved teleportation (this was not supposed to happen)",
      "bribed a maintenance drone",
      "followed the smell of coffee",
      "were attracted by the sound of unpaid invoices"
    ]

    "PIP INFESTATION (SPREAD): The Pips have #{spread_reasons.sample}. They seem... organized."
  end
end
