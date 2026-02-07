# frozen_string_literal: true

class AddMinesAndFactoriesToLaunchSystems < ActiveRecord::Migration[8.0]
  BUILDINGS = {
    "The Cradle" => [
      { name: "Cradle Mine",    function: "extraction", tier: 1, specialization: "Iron" },
      { name: "Cradle Factory", function: "refining",   tier: 1, specialization: "basic" }
    ],
    "Mira Station" => [
      { name: "Mira Factory",   function: "refining",   tier: 1, specialization: "basic" }
    ],
    "Verdant Gardens" => [
      { name: "Garden Mine",    function: "extraction", tier: 1, specialization: "Copper" },
      { name: "Garden Factory", function: "refining",   tier: 1, specialization: "electronics" }
    ],
    "Nexus Hub" => [
      { name: "Nexus Mine",     function: "extraction", tier: 1, specialization: "Aluminum" },
      { name: "Nexus Factory",  function: "refining",   tier: 1, specialization: "basic" }
    ],
    "Beacon Refinery" => [
      { name: "Beacon Factory", function: "refining",   tier: 2, specialization: "advanced" }
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
