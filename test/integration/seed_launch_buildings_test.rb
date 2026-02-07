# frozen_string_literal: true

require "test_helper"

class SeedLaunchBuildingsTest < ActiveSupport::TestCase
  test "all five launch systems exist as fixtures" do
    %i[cradle mira_station verdant_gardens nexus_hub beacon_refinery].each do |name|
      assert systems(name).present?, "#{name} fixture should exist"
    end
  end

  test "The Cradle is at the expected fixture coordinates" do
    cradle = systems(:cradle)
    assert_equal 500, cradle.x
    assert_equal 500, cradle.y
    assert_equal 500, cradle.z
  end

  test "systems are roughly 3-4 LY apart from The Cradle" do
    cradle = systems(:cradle)
    %i[mira_station verdant_gardens nexus_hub beacon_refinery].each do |name|
      system = systems(name)
      dx = system.x - cradle.x
      dy = system.y - cradle.y
      dz = system.z - cradle.z
      distance = Math.sqrt(dx**2 + dy**2 + dz**2)

      assert_in_delta 3.5, distance, 0.75,
        "#{system.name} should be 3-4 LY from Cradle (got #{distance.round(2)})"
    end
  end
end
