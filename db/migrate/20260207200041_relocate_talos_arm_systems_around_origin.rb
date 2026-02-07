# frozen_string_literal: true

class RelocateTalosArmSystemsAroundOrigin < ActiveRecord::Migration[8.0]
  COORDINATES = {
    "The Cradle"      => [0, 0, 0],
    "Mira Station"    => [3, 1, 0],
    "Verdant Gardens" => [-2, 3, 0],
    "Nexus Hub"       => [-1, -2, 3],
    "Beacon Refinery" => [2, -3, 1]
  }.freeze

  def up
    COORDINATES.each do |name, (x, y, z)|
      system = System.find_by(name: name)
      next unless system
      system.update!(x: x, y: y, z: z)
    end
  end

  def down
    # Previous coordinates are lost; no-op
  end
end
