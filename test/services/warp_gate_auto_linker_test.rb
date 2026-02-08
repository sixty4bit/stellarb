require "test_helper"

class WarpGateAutoLinkerTest < ActiveSupport::TestCase
  def create_system(name:, short_id:, x:, y:, z:)
    sys = System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
    @created_systems << sys
    sys
  end

  setup do
    @origin = systems(:cradle) # (500, 500, 500)
    @created_systems = []
  end

  teardown do
    ids = @created_systems.map(&:id) + [@origin.id]
    WarpGate.where(system_a_id: ids).or(WarpGate.where(system_b_id: ids)).delete_all
    @created_systems.each { |s| s.reload.destroy rescue nil }
  end

  # === Classification: Clear dominant axis ===

  test "classify_pyramid +X dominant" do
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, systems(:mira_station))
  end

  test "classify_pyramid +Y dominant" do
    # verdant_gardens: (498, 503, 500) => dx=-2, dy=3, dz=0
    assert_equal :pos_y, WarpGateAutoLinker.classify_pyramid(@origin, systems(:verdant_gardens))
  end

  test "classify_pyramid +Z dominant" do
    # nexus_hub: (499, 498, 503) => dx=-1, dy=-2, dz=3
    assert_equal :pos_z, WarpGateAutoLinker.classify_pyramid(@origin, systems(:nexus_hub))
  end

  test "classify_pyramid -X dominant" do
    sys = create_system(name: "NegX", short_id: "sy-nx1", x: 490, y: 500, z: 500)
    assert_equal :neg_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  test "classify_pyramid -Y dominant" do
    # beacon_refinery: (502, 497, 501) => dx=2, dy=-3, dz=1
    assert_equal :neg_y, WarpGateAutoLinker.classify_pyramid(@origin, systems(:beacon_refinery))
  end

  test "classify_pyramid -Z dominant" do
    sys = create_system(name: "NegZ", short_id: "sy-nz1", x: 500, y: 500, z: 490)
    assert_equal :neg_z, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  # === Tiebreaker: X > Y > Z ===

  test "tiebreaker X > Y when equal" do
    sys = create_system(name: "TieXY", short_id: "sy-txy", x: 505, y: 505, z: 500)
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  test "tiebreaker X > Z when equal" do
    sys = create_system(name: "TieXZ", short_id: "sy-txz", x: 505, y: 500, z: 505)
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  test "tiebreaker Y > Z when equal" do
    sys = create_system(name: "TieYZ", short_id: "sy-tyz", x: 500, y: 505, z: 505)
    assert_equal :pos_y, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  test "negative tiebreaker X > Y" do
    sys = create_system(name: "NTieXY", short_id: "sy-nxy", x: 495, y: 495, z: 500)
    assert_equal :neg_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  test "all axes zero returns pos_x" do
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, @origin)
  end

  # === find_nearest_in_pyramid ===

  test "finds nearest system in pyramid" do
    candidates = [systems(:mira_station), systems(:beacon_refinery), systems(:nexus_hub)]
    nearest = WarpGateAutoLinker.find_nearest_in_pyramid(@origin, :pos_x, candidates)
    assert_equal systems(:mira_station), nearest
  end

  test "returns nil when no candidates in pyramid" do
    candidates = [systems(:nexus_hub)] # +Z only
    nearest = WarpGateAutoLinker.find_nearest_in_pyramid(@origin, :neg_z, candidates)
    assert_nil nearest
  end

  test "selects closest when multiple in same pyramid" do
    close = create_system(name: "Close", short_id: "sy-cls", x: 501, y: 500, z: 500)
    far = create_system(name: "Far", short_id: "sy-far", x: 510, y: 500, z: 500)
    nearest = WarpGateAutoLinker.find_nearest_in_pyramid(@origin, :pos_x, [close, far])
    assert_equal close, nearest
  end

  # === link! integration ===

  test "link! creates gates to nearest in each pyramid" do
    sys_px = create_system(name: "PX", short_id: "sy-px1", x: 510, y: 500, z: 500)
    sys_ny = create_system(name: "NY", short_id: "sy-ny1", x: 500, y: 490, z: 500)
    sys_pz = create_system(name: "PZ", short_id: "sy-pz1", x: 500, y: 500, z: 510)

    WarpGate.create!(system_a: sys_px, system_b: sys_ny)
    WarpGate.create!(system_a: sys_ny, system_b: sys_pz)

    WarpGateAutoLinker.link!(@origin)

    assert WarpGate.between(@origin, sys_px), "Should link to +X"
    assert WarpGate.between(@origin, sys_ny), "Should link to -Y"
    assert WarpGate.between(@origin, sys_pz), "Should link to +Z"
  end

  test "link! does not create duplicate gates" do
    sys_px = create_system(name: "PX", short_id: "sy-px2", x: 510, y: 500, z: 500)
    WarpGate.create!(system_a: @origin, system_b: sys_px)

    assert_no_difference "WarpGate.count" do
      WarpGateAutoLinker.link!(@origin)
    end
  end

  test "link! selects closest in each pyramid" do
    close = create_system(name: "Close", short_id: "sy-cl3", x: 502, y: 500, z: 500)
    far = create_system(name: "Far", short_id: "sy-fr3", x: 520, y: 500, z: 500)
    WarpGate.create!(system_a: close, system_b: far)

    WarpGateAutoLinker.link!(@origin)
    assert WarpGate.between(@origin, close)
  end
end
