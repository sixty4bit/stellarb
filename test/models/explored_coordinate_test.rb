require "test_helper"

class ExploredCoordinateTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
  end

  test "validates presence of x, y, z" do
    coord = ExploredCoordinate.new(user: @user)

    assert_not coord.valid?
    assert_includes coord.errors[:x], "can't be blank"
    assert_includes coord.errors[:y], "can't be blank"
    assert_includes coord.errors[:z], "can't be blank"
  end

  test "validates uniqueness of coordinates per user" do
    @user.explored_coordinates.create!(x: 1, y: 2, z: 3)

    duplicate = @user.explored_coordinates.build(x: 1, y: 2, z: 3)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:x], "has already been taken"
  end

  test "different users can explore same coordinates" do
    other_user = users(:traveler)

    @user.explored_coordinates.create!(x: 1, y: 2, z: 3)
    coord = other_user.explored_coordinates.build(x: 1, y: 2, z: 3)

    assert coord.valid?
  end

  test "at scope finds coordinates at specific location" do
    @user.explored_coordinates.create!(x: 1, y: 2, z: 3)
    @user.explored_coordinates.create!(x: 4, y: 5, z: 6)

    result = @user.explored_coordinates.at(1, 2, 3)

    assert_equal 1, result.count
    assert_equal [1, 2, 3], [result.first.x, result.first.y, result.first.z]
  end
end
