require "test_helper"

class WarpGateAutoLinkerTest < ActiveSupport::TestCase
  def create_system(name:, short_id:, x:, y:, z:)
    sys = System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
    @created_systems << sys
    sys
  end

  setup do
    @origin = systems(:cradle)
    @created_systems = []
  end

  teardown do
    # Clean up warp gates first, then systems
    ids = @created_systems.map(&:id) + [@origin.id]
    WarpGate.where(system_a_id: ids).or(WarpGate.where(system_b_id: ids)).delete_all
    @created_systems.each { |s| s.reload.destroy rescue nil }
  end

  test "classify_pyramid +X dominant" do
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, systems(:mira_station))
  end

  test "classify_pyramid tiebreaker X > Y" do
    sys = create_system(name: "TieXY", short_id: "sy-txy", x: 505, y: 505, z: 500)
    assert_equal :pos_x, WarpGateAutoLinker.classify_pyramid(@origin, sys)
  end

  test "link! creates gates to nearest in each pyramid" do
    sys_px = create_system(name: "PX", short_id: "sy-px1", x: 510, y: 500, z: 500)
    sys_ny = create_system(name: "NY", short_id: "sy-ny1", x: 500, y: 490, z: 500)
    sys_pz = create_system(name: "PZ", short_id: "sy-pz1", x: 500, y: 500, z: 510)

    # Make them gated
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
