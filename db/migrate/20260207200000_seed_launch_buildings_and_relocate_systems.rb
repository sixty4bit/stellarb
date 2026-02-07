# frozen_string_literal: true

class SeedLaunchBuildingsAndRelocateSystems < ActiveRecord::Migration[8.0]
  # Coordinate updates for Talos Arm systems (3-4 LY from Cradle)
  # All coordinates positive (System validates 0..999999)
  # Distances from Cradle (0,0,0): Mira 3.16, Verdant 3.32, Nexus 3.74, Beacon 3.61 LY
  SYSTEM_COORDS = {
    "The Cradle"      => { x: 0, y: 0, z: 0 },
    "Mira Station"    => { x: 3, y: 1, z: 0 },
    "Verdant Gardens" => { x: 1, y: 3, z: 1 },
    "Nexus Hub"       => { x: 2, y: 1, z: 3 },
    "Beacon Refinery" => { x: 3, y: 0, z: 2 }
  }.freeze

  OLD_COORDS = {
    "Mira Station"    => { x: 3, y: 2, z: 0 },
    "Verdant Gardens" => { x: 2, y: 3, z: 1 },
    "Nexus Hub"       => { x: 1, y: 3, z: 2 },
    "Beacon Refinery" => { x: 1, y: 2, z: 1 }
  }.freeze

  def up
    # Make user_id nullable for NPC buildings
    change_column_null :buildings, :user_id, true

    # Relocate systems
    SYSTEM_COORDS.each do |name, coords|
      system = System.find_by(name: name)
      next unless system
      system.update_columns(coords)
    end

    # Seed NPC buildings per system
    seed_buildings!
  end

  def down
    # Remove NPC buildings
    Building.where(user_id: nil).delete_all

    # Revert coordinates
    OLD_COORDS.each do |name, coords|
      system = System.find_by(name: name)
      next unless system
      system.update_columns(coords)
    end

    # Revert user_id to not null (only if no nil user_ids remain)
    change_column_null :buildings, :user_id, false, 0
  end

  private

  def seed_buildings!
    buildings_config = {
      "The Cradle" => [
        { name: "Civic Center",   function: "civic",     tier: 2 },
        { name: "Logistics Hub",  function: "logistics", tier: 1 },
        { name: "Defense Station", function: "defense",  tier: 1 }
      ],
      "Mira Station" => [
        { name: "Civic Center",       function: "civic",      tier: 1 },
        { name: "Extraction Facility", function: "extraction", tier: 2, specialization: "Iron" },
        { name: "Deep Core Extractor", function: "extraction", tier: 1, specialization: "Copper" }
      ],
      "Verdant Gardens" => [
        { name: "Civic Center",        function: "civic",      tier: 1 },
        { name: "Extraction Facility", function: "extraction", tier: 1, specialization: "Carbon" },
        { name: "Logistics Hub",       function: "logistics",  tier: 1 }
      ],
      "Nexus Hub" => [
        { name: "Civic Center",   function: "civic",    tier: 3 },
        { name: "Logistics Hub",  function: "logistics", tier: 2 },
        { name: "Defense Station", function: "defense",  tier: 1 }
      ],
      "Beacon Refinery" => [
        { name: "Civic Center",        function: "civic",      tier: 1 },
        { name: "Refining Facility",   function: "refining",   tier: 2, specialization: "basic" },
        { name: "Extraction Facility", function: "extraction", tier: 1, specialization: "Iron" }
      ]
    }

    buildings_config.each do |system_name, buildings|
      system = System.find_by(name: system_name)
      next unless system

      buildings.each do |config|
        building = Building.find_or_initialize_by(
          system_id: system.id,
          name: config[:name],
          function: config[:function],
          user_id: nil
        )
        next if building.persisted?

        building.assign_attributes(
          tier: config[:tier],
          race: "vex",
          status: "active",
          uuid: SecureRandom.uuid,
          specialization: config[:specialization]
        )
        # Let callbacks handle short_id and building_attributes
        building.save!(validate: false)

        # Ensure building_attributes are set
        if building.building_attributes.blank?
          building.regenerate_building_attributes!
          building.save!(validate: false)
        end
      end
    end
  end
end
