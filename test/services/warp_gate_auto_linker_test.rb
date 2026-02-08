require "test_helper"

class WarpGateAutoLinkerTest < ActiveSupport::TestCase
  setup do
    @origin = systems(:cradle) # (500, 500, 500)
  end

  # Helper to create test systems with properties pre-set (avoids ProceduralGeneration validation)
  def create_system(name:, short_id:, x:, y:, z:)
    System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
  end

  # === Classification Tests ===

  test "classifies +X dominant axis as pos_x" do
    target = systems(:mira_station) # (503, 501, 500) — dx=3, dy=1, dz=0
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, target)
  end

  test "classifies +Y dominant axis as pos_y" do
    target = systems(:verdant_gardens) # (498, 503, 500) — dx=-2, dy=3
    assert_equal :pos_y, WarpGateAutoLinker.classify_pyramid(@origin, target)
  end

  test "classifies +Z dominant axis as pos_z" do
    target = systems(:nexus_hub) # (499, 498, 503) — dx=-1, dy=-2, dz=3
    assert_equal :pos_z, WarpGateAutoLinker.classify_pyramid(@origin, target)
  end

  test "classifies -Y dominant axis as neg_y" do
    target = systems(:beacon_refinery) # (502, 497, 501) — dx=2, dy=-3, dz=1
    assert_equal :neg_y, WarpGateAutoLinker.classify_pyramid(@origin, target)
  end

  test "tiebreaker X > Y when equal" do
    sys = create_system(name: "TieXY", short_id: "sy-txy", x: 505, y: 505, z: 500)
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  ensure
    sys&.destroy
  end

  test "tiebreaker X > Z when equal" do
    sys = create_system(name: "TieXZ", short_id: "sy-txz", x: 505, y: 500, z: 505)
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  ensure
    sys&.destroy
  end

  test "tiebreaker Y > Z when equal" do
    sys = create_system(name: "TieYZ", short_id: "sy-tyz", x: 500, y: 505, z: 505)
    assert_equal :pos_y, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  ensure
    sys&.destroy
  end

  test "negative tiebreaker X > Y" do
    sys = create_system(name: "NegTieXY", short_id: "sy-nxy", x: 495, y: 495, z: 500)
    assert_equal :neg_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  ensure
    sys&.destroy
  end

  test "all axes zero returns pos_x" do
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, @origin)
  end

  # === find_nearest_in_pyramid Tests ===

  test "finds nearest system in pyramid" do
    candidates = [systems(:mira_station), systems(:beacon_refinery), systems(:nexus_hub)]
    nearest = WarpGateAutoLinker.find_nearest_in_pyramid(@origin, :pos_x, candidates)
    assert_equal systems(:mira_station), nearest
  end

  test "returns nil when no candidates in pyramid" do
    candidates = [systems(:nexus_hub)]
    nearest = WarpGateAutoLinker.find_nearest_in_pyramid(@origin, :neg_z, candidates)
    assert_nil nearest
  end

  test "selects closest when multiple in same pyramid" do
    close = create_system(name: "Close", short_id: "sy-cls", x: 501, y: 500, z: 500)
    far = create_system(name: "Far", short_id: "sy-far", x: 510, y: 500, z: 500)
    nearest = WarpGateAutoLinker.find_nearest_in_pyramid(@origin, :pos_x, [close, far])
    assert_equal close, nearest
  ensure
    close&.destroy
    far&.destroy
  end
end
