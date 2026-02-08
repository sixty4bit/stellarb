require "test_helper"

class ExplorationServiceRealizeTest < ActiveSupport::TestCase
  def create_system(name:, short_id:, x:, y:, z:)
    System.create!(name: name, short_id: short_id, x: x, y: y, z: z,
                   properties: { star_type: "red_dwarf", planet_count: 1, hazard_level: 0, base_prices: {} })
  end

  setup do
    @user = users(:one)
    @ship = ships(:hauler)
    @origin = systems(:cradle)
    @ship.update_columns(
      current_system_id: @origin.id,
      location_x: @origin.x, location_y: @origin.y, location_z: @origin.z,
      fuel: 100.0, status: "docked"
    )
  end

  test "realize_and_arrive! with pre-existing system docks ship there" do
    target_sys = create_system(name: "Target", short_id: "sy-tgt", x: 501, y: 500, z: 500)
    @ship.update_columns(location_x: 501, location_y: 500, location_z: 500, current_system_id: nil, status: "docked")

    service = ExplorationService.new(@user, @ship)
    service.realize_and_arrive!(@ship)
    @ship.reload

    assert_equal target_sys.id, @ship.current_system_id
    assert SystemVisit.exists?(user: @user, system: target_sys)
    assert ExploredCoordinate.explored?(user: @user, x: 501, y: 500, z: 500)
  end

  test "realize_and_arrive! discovers new system at unvisited coordinates" do
    System.where(x: 777, y: 888, z: 999).delete_all
    @ship.update_columns(location_x: 777, location_y: 888, location_z: 999, current_system_id: nil, status: "docked")

    service = ExplorationService.new(@user, @ship)
    service.realize_and_arrive!(@ship)
    @ship.reload

    # System should be discovered and ship docked
    new_sys = System.find_by(x: 777, y: 888, z: 999)
    assert new_sys.present?, "Should discover system"
    assert_equal new_sys.id, @ship.current_system_id
    assert SystemVisit.exists?(user: @user, system: new_sys)
    assert ExploredCoordinate.explored?(user: @user, x: 777, y: 888, z: 999)
  end

  test "realize_and_arrive! creates explored coordinate" do
    System.where(x: 333, y: 444, z: 555).delete_all
    @ship.update_columns(location_x: 333, location_y: 444, location_z: 555, current_system_id: nil, status: "docked")

    service = ExplorationService.new(@user, @ship)
    service.realize_and_arrive!(@ship)

    coord = ExploredCoordinate.find_by(user: @user, x: 333, y: 444, z: 555)
    assert coord.present?
    assert coord.has_system
  end
end
