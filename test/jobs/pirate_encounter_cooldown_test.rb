# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/talos_arm"

class PirateEncounterCooldownTest < ActiveJob::TestCase
  setup do
    @user = users(:one)

    @dangerous_system = System.create!(
      name: "Pirate Test Zone",
      short_id: "sy-pct",
      x: 800, y: 800, z: 800,
      properties: {
        "star_type" => "red_giant",
        "hazard_level" => 80
      }
    )

    @ship = Ship.create!(
      user: @user,
      name: "Cooldown Test Ship",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100 }
    )
  end

  test "encounter skipped during cooldown period" do
    # Create a recent combat message (simulating a recent encounter)
    Message.create!(
      user: @user,
      title: "Pirates!",
      body: "test",
      from: "Security Alert",
      category: "combat"
    )

    result = PirateEncounterJob.new.perform(@ship, force_encounter: 0.0)
    assert_equal :cooldown, result[:outcome]
  end

  test "encounter allowed after cooldown expires" do
    # Create an old combat message outside cooldown window
    Message.create!(
      user: @user,
      title: "Pirates!",
      body: "test",
      from: "Security Alert",
      category: "combat",
      created_at: 31.minutes.ago
    )

    result = PirateEncounterJob.new.perform(@ship, force_encounter: 0.0, force_marine_roll: 200)
    assert_equal :repelled, result[:outcome]
  end

  test "cooldown constant is 30 minutes" do
    assert_equal 30, PirateEncounterJob::ENCOUNTER_COOLDOWN_MINUTES
  end

  test "tutorial hazard levels are reduced in seeds" do
    # Verify the seed constants have reduced hazard levels
    systems = Seeds::TalosArm::SYSTEMS
    verdant = systems.find { |s| s[:name] == "Verdant Gardens" }
    mira = systems.find { |s| s[:name] == "Mira Station" }
    nexus = systems.find { |s| s[:name] == "Nexus Hub" }
    beacon = systems.find { |s| s[:name] == "Beacon Refinery" }

    assert_equal 2, verdant[:properties][:hazard_level], "Verdant should be 2%"
    assert_equal 3, mira[:properties][:hazard_level], "Mira should be 3%"
    assert_equal 5, nexus[:properties][:hazard_level], "Nexus should be 5%"
    assert_equal 8, beacon[:properties][:hazard_level], "Beacon should be 8%"
  end
end
