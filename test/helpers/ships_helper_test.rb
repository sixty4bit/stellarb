require "test_helper"
require "ostruct"

class ShipsHelperTest < ActionView::TestCase
  test "fuel_color_class returns red for fuel below 10%" do
    ship = OpenStruct.new(fuel: 9, fuel_capacity: 100)
    assert_equal "text-red-500", fuel_color_class(ship)
  end

  test "fuel_color_class returns yellow for fuel between 10% and 25%" do
    ship = OpenStruct.new(fuel: 15, fuel_capacity: 100)
    assert_equal "text-yellow-500", fuel_color_class(ship)

    ship = OpenStruct.new(fuel: 24, fuel_capacity: 100)
    assert_equal "text-yellow-500", fuel_color_class(ship)
  end

  test "fuel_color_class returns lime for fuel 25% and above" do
    ship = OpenStruct.new(fuel: 25, fuel_capacity: 100)
    assert_equal "text-lime-400", fuel_color_class(ship)

    ship = OpenStruct.new(fuel: 100, fuel_capacity: 100)
    assert_equal "text-lime-400", fuel_color_class(ship)
  end

  test "fuel_color_class handles zero capacity" do
    ship = OpenStruct.new(fuel: 0, fuel_capacity: 0)
    assert_equal "text-lime-400", fuel_color_class(ship)
  end

  test "fuel_bar_color_class returns red for fuel below 10%" do
    ship = OpenStruct.new(fuel: 5, fuel_capacity: 100)
    assert_equal "bg-red-500", fuel_bar_color_class(ship)
  end

  test "fuel_bar_color_class returns yellow for fuel between 10% and 25%" do
    ship = OpenStruct.new(fuel: 20, fuel_capacity: 100)
    assert_equal "bg-yellow-500", fuel_bar_color_class(ship)
  end

  test "fuel_bar_color_class returns lime for fuel 25% and above" do
    ship = OpenStruct.new(fuel: 50, fuel_capacity: 100)
    assert_equal "bg-lime-500", fuel_bar_color_class(ship)
  end
end
