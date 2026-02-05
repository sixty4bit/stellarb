require "test_helper"

class ShipCargoTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @system = System.cradle
    @ship = Ship.create!(
      name: "Cargo Ship",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 50,
      fuel_capacity: 100,
      status: "docked",
      current_system: @system,
      ship_attributes: { "cargo_capacity" => 200 }
    )
  end

  test "cargo_capacity returns value from ship_attributes" do
    assert_equal 200, @ship.cargo_capacity
  end

  test "total_cargo_weight sums all cargo" do
    @ship.update!(cargo: { "ore" => 50, "water" => 30, "food" => 20 })
    
    assert_equal 100, @ship.total_cargo_weight
  end

  test "total_cargo_weight returns 0 for empty cargo" do
    @ship.update!(cargo: {})
    
    assert_equal 0, @ship.total_cargo_weight
  end

  test "available_cargo_space returns remaining capacity" do
    @ship.update!(cargo: { "ore" => 50 })
    
    assert_equal 150, @ship.available_cargo_space
  end

  test "add_cargo! adds to existing cargo" do
    @ship.update!(cargo: { "ore" => 30 })
    
    result = @ship.add_cargo!("ore", 20)
    
    assert result.success?
    assert_equal 50, @ship.reload.cargo["ore"]
  end

  test "add_cargo! creates new cargo entry" do
    @ship.update!(cargo: {})
    
    result = @ship.add_cargo!("water", 25)
    
    assert result.success?
    assert_equal 25, @ship.reload.cargo["water"]
  end

  test "add_cargo! fails if exceeds capacity" do
    @ship.update!(cargo: { "ore" => 180 })
    
    result = @ship.add_cargo!("water", 50)
    
    assert_not result.success?
    assert_match /exceed.*capacity/i, result.error
    assert_nil @ship.reload.cargo["water"]
  end

  test "remove_cargo! removes from cargo" do
    @ship.update!(cargo: { "ore" => 50 })
    
    result = @ship.remove_cargo!("ore", 20)
    
    assert result.success?
    assert_equal 30, @ship.reload.cargo["ore"]
  end

  test "remove_cargo! removes entry when quantity reaches 0" do
    @ship.update!(cargo: { "ore" => 20 })
    
    result = @ship.remove_cargo!("ore", 20)
    
    assert result.success?
    assert_not @ship.reload.cargo.key?("ore")
  end

  test "remove_cargo! fails if insufficient quantity" do
    @ship.update!(cargo: { "ore" => 10 })
    
    result = @ship.remove_cargo!("ore", 20)
    
    assert_not result.success?
    assert_match /insufficient/i, result.error
    assert_equal 10, @ship.reload.cargo["ore"]
  end

  test "remove_cargo! fails if commodity not in cargo" do
    @ship.update!(cargo: {})
    
    result = @ship.remove_cargo!("water", 10)
    
    assert_not result.success?
    assert_match /don't have/i, result.error
  end

  test "cargo_quantity_for returns quantity of specific commodity" do
    @ship.update!(cargo: { "ore" => 50, "water" => 30 })
    
    assert_equal 50, @ship.cargo_quantity_for("ore")
    assert_equal 30, @ship.cargo_quantity_for("water")
  end

  test "cargo_quantity_for returns 0 for missing commodity" do
    @ship.update!(cargo: {})
    
    assert_equal 0, @ship.cargo_quantity_for("electronics")
  end
end
