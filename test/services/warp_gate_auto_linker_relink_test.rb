require "test_helper"

class WarpGateAutoLinkerRelinkTest < ActiveSupport::TestCase
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

  test "relink_neighbors! replaces farther link with closer new system" do
    # neighbor at (505, 500, 500), currently linked to far at (520, 500, 500)
    # New system origin at (500, 500, 500) — in neighbor's neg_x pyramid
    # neighbor->far in neg_x? No: far is at 520, neighbor at 505, so far is +x from neighbor.
    # Let's set up correctly:
    # neighbor(505,500,500), old_link(490,500,500) — old_link is in neg_x from neighbor (dx=-15)
    # origin(500,500,500) — also in neg_x from neighbor (dx=-5), but CLOSER
    neighbor = create_system(name: "Neighbor", short_id: "sy-rnb", x: 505, y: 500, z: 500)
    old_link = create_system(name: "OldLink", short_id: "sy-rol", x: 490, y: 500, z: 500)

    # existing gate: neighbor <-> old_link
    WarpGate.create!(system_a: neighbor, system_b: old_link)

    # Now add origin as a new gated system
    # origin needs to be "gated" — create a gate to some other system
    other = create_system(name: "Other", short_id: "sy-oth", x: 500, y: 510, z: 500)
    WarpGate.create!(system_a: @origin, system_b: other)

    WarpGateAutoLinker.relink_neighbors!(@origin)

    # neighbor should now link to origin (closer in neg_x) instead of old_link
    assert WarpGate.between(neighbor, @origin), "Neighbor should relink to closer origin"
  end

  test "unlink! removes all gates for system" do
    sys = create_system(name: "Unlinkee", short_id: "sy-unl", x: 505, y: 500, z: 500)
    WarpGate.create!(system_a: @origin, system_b: sys)
    assert WarpGate.between(@origin, sys)

    WarpGateAutoLinker.unlink!(sys)
    assert_nil WarpGate.between(@origin, sys)
  end

  test "unlink! triggers neighbors to find replacement" do
    a = create_system(name: "A", short_id: "sy-ua", x: 505, y: 500, z: 500)
    b = create_system(name: "B", short_id: "sy-ub", x: 510, y: 500, z: 500)
    c = create_system(name: "C", short_id: "sy-uc", x: 515, y: 500, z: 500)

    WarpGate.create!(system_a: a, system_b: b)
    WarpGate.create!(system_a: b, system_b: c)

    WarpGateAutoLinker.unlink!(b)

    assert_nil WarpGate.between(a, b)
    assert WarpGate.between(a, c), "A should link to C as replacement"
  end
end
