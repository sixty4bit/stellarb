# frozen_string_literal: true

require "test_helper"
require_relative "../../db/migrate/20260207200000_seed_launch_buildings_and_relocate_systems"

class SeedLaunchBuildingsTest < ActiveSupport::TestCase
  # We test by running the migration logic directly against test fixtures.
  # The Cradle fixture exists; we create the other 4 systems.

  setup do
    @cradle = systems(:cradle)
    # Update Cradle to expected coords
    @cradle.update_columns(x: 0, y: 0, z: 0)

    # Create Talos Arm systems at OLD coords (pre-migration)
    @mira = System.create!(name: "Mira Station", short_id: "sy-mir", x: 13, y: 12, z: 10,
      properties: { star_type: "red_dwarf", planet_count: 3, hazard_level: 10 })
    @verdant = System.create!(name: "Verdant Gardens", short_id: "sy-ver", x: 12, y: 13, z: 11,
      properties: { star_type: "yellow_dwarf", planet_count: 5, hazard_level: 5 })
    @nexus = System.create!(name: "Nexus Hub", short_id: "sy-nex", x: 11, y: 13, z: 12,
      properties: { star_type: "blue_giant", planet_count: 4, hazard_level: 15 })
    @beacon = System.create!(name: "Beacon Refinery", short_id: "sy-bea", x: 11, y: 12, z: 11,
      properties: { star_type: "orange_dwarf", planet_count: 2, hazard_level: 20 })

    # Run the migration logic
    migration = SeedLaunchBuildingsAndRelocateSystems.new
    migration.up
  end

  EXPECTED_COORDS = {
    "The Cradle"      => [0, 0, 0],
    "Mira Station"    => [3, 1, 0],
    "Verdant Gardens" => [1, 3, 1],
    "Nexus Hub"       => [2, 1, 3],
    "Beacon Refinery" => [3, 0, 2]
  }.freeze

  test "all launch systems have correct coordinates after migration" do
    EXPECTED_COORDS.each do |name, (x, y, z)|
      system = System.find_by(name: name)
      assert system, "System '#{name}' should exist"
      assert_equal [x, y, z], [system.x, system.y, system.z],
        "#{name} should be at (#{x},#{y},#{z})"
    end
  end

  test "all launch systems have expected NPC buildings" do
    expected = {
      "The Cradle" => [
        { name: "Civic Center", function: "civic", tier: 2 },
        { name: "Logistics Hub", function: "logistics", tier: 1 },
        { name: "Defense Station", function: "defense", tier: 1 }
      ],
      "Mira Station" => [
        { name: "Civic Center", function: "civic", tier: 1 },
        { name: "Extraction Facility", function: "extraction", tier: 2 },
        { name: "Deep Core Extractor", function: "extraction", tier: 1 }
      ],
      "Verdant Gardens" => [
        { name: "Civic Center", function: "civic", tier: 1 },
        { name: "Extraction Facility", function: "extraction", tier: 1 },
        { name: "Logistics Hub", function: "logistics", tier: 1 }
      ],
      "Nexus Hub" => [
        { name: "Civic Center", function: "civic", tier: 3 },
        { name: "Logistics Hub", function: "logistics", tier: 2 },
        { name: "Defense Station", function: "defense", tier: 1 }
      ],
      "Beacon Refinery" => [
        { name: "Civic Center", function: "civic", tier: 1 },
        { name: "Refining Facility", function: "refining", tier: 2 },
        { name: "Extraction Facility", function: "extraction", tier: 1 }
      ]
    }

    expected.each do |system_name, buildings|
      system = System.find_by(name: system_name)
      assert system, "System '#{system_name}' should exist"

      npc_buildings = system.buildings.where(user_id: nil)

      buildings.each do |exp|
        building = npc_buildings.find_by(name: exp[:name], function: exp[:function], tier: exp[:tier])
        assert building,
          "#{system_name} should have NPC building: #{exp[:name]} (#{exp[:function]} T#{exp[:tier]})"
        assert_equal "vex", building.race
        assert_equal "active", building.status
        assert_nil building.user_id
        assert building.building_attributes.present?,
          "#{exp[:name]} in #{system_name} should have building_attributes"
      end
    end
  end

  test "systems are 3-4 LY apart from The Cradle" do
    cradle = System.find_by(name: "The Cradle")

    ["Mira Station", "Verdant Gardens", "Nexus Hub", "Beacon Refinery"].each do |name|
      system = System.find_by(name: name)
      assert system, "#{name} should exist"

      distance = Math.sqrt(
        (system.x - cradle.x)**2 +
        (system.y - cradle.y)**2 +
        (system.z - cradle.z)**2
      )
      assert distance >= 3.0 && distance <= 4.0,
        "#{name} should be 3-4 LY from The Cradle (was #{distance.round(2)})"
    end
  end

  test "migration is idempotent" do
    # Run again
    migration = SeedLaunchBuildingsAndRelocateSystems.new
    migration.up

    # Should still have same number of NPC buildings (15 total)
    assert_equal 15, Building.where(user_id: nil).count
  end
end
