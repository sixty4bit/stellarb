# frozen_string_literal: true

# Daily job rolling 1% chance per asset for pip infestation.
# Implements the "Pip Factor" from ROADMAP Section 15.1.
#
# Pip infestations are an anti-automation mechanic that forces player attention.
# When triggered, the asset is disabled and requires physical presence to purge.
class PipInfestationJob < ApplicationJob
  queue_as :default

  # The 1% Rule - chance per asset per day for pip infestation
  PIP_CHANCE = 0.01

  class << self
    # Check if a pip infestation should occur (1% chance)
    def should_pip_infest?
      rand < PIP_CHANCE
    end
  end

  def perform
    results = {
      assets_processed: 0,
      incidents_created: 0,
      ships_processed: 0,
      buildings_processed: 0
    }

    # Process all operational ships
    Ship.operational.find_each do |ship|
      results[:assets_processed] += 1
      results[:ships_processed] += 1

      if should_process?(ship)
        create_pip_infestation(ship)
        results[:incidents_created] += 1
      end
    end

    # Process all operational buildings
    Building.operational.find_each do |building|
      results[:assets_processed] += 1
      results[:buildings_processed] += 1

      if should_process?(building)
        create_pip_infestation(building)
        results[:incidents_created] += 1
      end
    end

    results
  end

  private

  # Check if we should create a pip infestation for this asset
  def should_process?(asset)
    # Skip if already has an unresolved pip infestation
    return false if has_active_pip_infestation?(asset)

    # Roll the 1% chance
    self.class.should_pip_infest?
  end

  # Check if asset already has an active pip infestation
  def has_active_pip_infestation?(asset)
    Incident.pip_infestations.unresolved.exists?(asset: asset)
  end

  # Create a pip infestation incident for the asset
  def create_pip_infestation(asset)
    description = generate_pip_description(asset)

    Incident.create!(
      asset: asset,
      severity: 5, # Pip infestations are always T5 catastrophes
      description: description,
      is_pip_infestation: true
    )

    # Note: The Incident model's after_create callback will disable the asset
  end

  # Generate a humorous pip infestation description
  def generate_pip_description(asset)
    CatastropheGenerator.generate_pip_description
  rescue NameError
    # Fallback if CatastropheGenerator doesn't exist yet
    generate_fallback_description(asset)
  end

  # Fallback description generator
  def generate_fallback_description(asset)
    critical_systems = %w[
      Engine Navigation Sensors Cargo\ Bay Reactor Life\ Support
      Communications Weapons Shields Power\ Coupling Airlock
    ]

    absurd_actions = [
      "built a nest inside",
      "rewired",
      "filled with fluff",
      "converted into a playground",
      "decorated with sparkles",
      "turned into a hot tub",
      "stuffed with stolen socks",
      "replaced with cheese"
    ]

    consequences = [
      "it now plays circus music at full volume",
      "the entire system smells like burnt popcorn",
      "crew members keep slipping on mystery goo",
      "all displays now show only cat videos",
      "the autopilot insists on flying towards the nearest supernova",
      "everything tastes like purple",
      "the coffee machine has become sentient and hostile",
      "all communications are translated to interpretive dance"
    ]

    system = critical_systems.sample
    action = absurd_actions.sample
    consequence = consequences.sample

    "PIP INFESTATION: #{system} is offline. The Pips have #{action} it, and now #{consequence}."
  end
end
