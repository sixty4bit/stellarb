# frozen_string_literal: true

require "test_helper"

class BuildingPriceModifierTest < ActiveSupport::TestCase
  setup do
    @building = buildings(:mining_facility)
  end

  test "price_modifier_for returns Float" do
    result = @building.price_modifier_for("iron")

    assert_instance_of Float, result
  end

  test "price_modifier_for returns 1.0 by default" do
    assert_equal 1.0, @building.price_modifier_for("iron")
    assert_equal 1.0, @building.price_modifier_for("fuel")
    assert_equal 1.0, @building.price_modifier_for("electronics")
  end

  test "price_modifier_for handles nil commodity gracefully" do
    result = @building.price_modifier_for(nil)

    assert_instance_of Float, result
    assert_equal 1.0, result
  end

  test "price_modifier_for handles unknown commodity gracefully" do
    result = @building.price_modifier_for("nonexistent_commodity_xyz")

    assert_instance_of Float, result
    assert_equal 1.0, result
  end
end
