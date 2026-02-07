# frozen_string_literal: true

require "test_helper"

class ShipsRaceUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
  end

  test "new ship page shows all 6 races with descriptions" do
    get new_ship_path
    assert_response :success

    assert_select "[data-testid='race-vex']", text: /Versatile and balanced/
    assert_select "[data-testid='race-solari']", text: /Advanced sensor arrays/
    assert_select "[data-testid='race-krog']", text: /Built like a tank/
    assert_select "[data-testid='race-myrmidon']", text: /Efficient manufacturing/
    assert_select "[data-testid='race-grelmak']", text: /Scrapyard genius/
    assert_select "[data-testid='race-mechari']", text: /Precision robotics/
  end

  test "new ship page shows chaos warning for Grelmak" do
    get new_ship_path
    assert_response :success
    assert_select "[data-testid='race-grelmak'] .text-orange-400", text: /Chaos Factor/
  end

  test "new ship page shows efficiency badge for Mechari" do
    get new_ship_path
    assert_response :success
    assert_select "[data-testid='race-mechari'] .text-sky-400", text: /Ultra-efficient/
  end

  test "new ship page shows crew limitation for Mechari" do
    get new_ship_path
    assert_response :success
    assert_select "[data-testid='race-mechari']", text: /limited crew capacity/
  end

  test "show page displays race with flavor text" do
    ship = ships(:hauler)
    get ship_path(ship)
    assert_response :success
    assert_select "[data-testid='race-flavor']"
  end

  test "show page displays chaos indicator for Grelmak ship" do
    ship = ships(:hauler)
    # Update ship to grelmak for this test
    ship.update_column(:race, "grelmak")
    get ship_path(ship)
    assert_response :success
    assert_select "[data-testid='chaos-indicator']", text: /Chaos/
  end
end
