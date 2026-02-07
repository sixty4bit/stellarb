# frozen_string_literal: true

class CreateNpcBuildingsForLaunchSystems < ActiveRecord::Migration[8.0]
  BUILDINGS = {
    "The Cradle" => [
      { name: "Civic Center",     function: "civic",      tier: 2 },
      { name: "Logistics Hub",    function: "logistics",  tier: 1 },
      { name: "Defense Station",  function: "defense",    tier: 1 }
    ],
    "Mira Station" => [
      { name: "Ore Extraction",   function: "extraction", tier: 2, specialization: "Iron" },
      { name: "Mira Depot",       function: "logistics",  tier: 1 },
      { name: "Mira Defense",     function: "defense",    tier: 1 }
    ],
    "Verdant Gardens" => [
      { name: "Garden Civic",     function: "civic",      tier: 1 },
      { name: "Garden Depot",     function: "logistics",  tier: 1 },
      { name: "Garden Defense",   function: "defense",    tier: 1 }
    ],
    "Nexus Hub" => [
      { name: "Trade Center",     function: "civic",      tier: 2 },
      { name: "Nexus Logistics",  function: "logistics",  tier: 2 },
      { name: "Nexus Defense",    function: "defense",    tier: 1 }
    ],
    "Beacon Refinery" => [
      { name: "Beacon Extractor", function: "extraction", tier: 1, specialization: "Tungsten" },
      { name: "Beacon Depot",     function: "logistics",  tier: 1 },
      { name: "Beacon Defense",   function: "defense",    tier: 1 }
    ]
  }.freeze

  def up
    BUILDINGS.each do |system_name, buildings|
      system = System.find_by(name: system_name)
      next unless system

      buildings.each do |config|
        next if Building.exists?(system: system, name: config[:name])

        Building.insert!({
          system_id: system.id,
          user_id: nil,
          name: config[:name],
          function: config[:function],
          race: "vex",
          tier: config[:tier],
          status: "active",
          specialization: config[:specialization],
          short_id: "bd-#{SecureRandom.hex(3)}",
          uuid: SecureRandom.uuid_v7,
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
  end

  def down
    BUILDINGS.each do |system_name, buildings|
      system = System.find_by(name: system_name)
      next unless system

      buildings.each do |config|
        Building.where(system: system, name: config[:name], user_id: nil).delete_all
      end
    end
  end
end
