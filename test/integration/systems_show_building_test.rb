require "test_helper"

class SystemsShowBuildingTest < ActionDispatch::IntegrationTest
  test "systems show page renders when a building has nil short_id" do
    user = users(:pilot)
    system = systems(:cradle)

    # Create a building with nil short_id to simulate the bug
    building = Building.create!(
      user: nil,
      system: system,
      name: "NPC Outpost",
      short_id: "bl-npc1",
      uuid: Building.generate_uuid7,
      race: "vex",
      function: "defense",
      tier: 1,
      status: "active"
    )
    # Force nil short_id to reproduce the error
    building.update_column(:short_id, nil)

    sign_in_as(user)
    get system_path(system)
    assert_response :success
  end

  test "systems show page renders buildings with valid short_ids" do
    user = users(:pilot)
    system = systems(:cradle)

    sign_in_as(user)
    get system_path(system)
    assert_response :success
    assert_select "a", text: /Alpha Mine/
  end
end
