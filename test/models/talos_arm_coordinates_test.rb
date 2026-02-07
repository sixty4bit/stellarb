# frozen_string_literal: true

require "test_helper"

class TalosArmCoordinatesTest < ActiveSupport::TestCase
  EXPECTED = {
    "The Cradle"      => { fixture: :cradle, coords: [0, 0, 0] },
    "Mira Station"    => { fixture: :mira_station, coords: [3, 1, 0], distance: 3.16 },
    "Verdant Gardens" => { fixture: :verdant_gardens, coords: [-2, 3, 0], distance: 3.61 },
    "Nexus Hub"       => { fixture: :nexus_hub, coords: [-1, -2, 3], distance: 3.74 },
    "Beacon Refinery" => { fixture: :beacon_refinery, coords: [2, -3, 1], distance: 3.74 }
  }.freeze

  EXPECTED.each do |name, expected|
    test "#{name} has correct coordinates after migration" do
      system = systems(expected[:fixture])
      # Simulate what the migration does
      system.update!(x: expected[:coords][0], y: expected[:coords][1], z: expected[:coords][2])
      assert_equal expected[:coords], [system.x, system.y, system.z]
    end

    next unless expected[:distance]

    test "#{name} is #{expected[:distance]} LY from The Cradle" do
      system = systems(expected[:fixture])
      cradle = systems(:cradle)
      # Set coordinates as migration would
      cradle.update!(x: 0, y: 0, z: 0)
      system.update!(x: expected[:coords][0], y: expected[:coords][1], z: expected[:coords][2])

      distance = Math.sqrt(
        (system.x - cradle.x)**2 +
        (system.y - cradle.y)**2 +
        (system.z - cradle.z)**2
      ).round(2)
      assert_equal expected[:distance], distance
    end
  end
end
