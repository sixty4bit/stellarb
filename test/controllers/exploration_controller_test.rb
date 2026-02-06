# frozen_string_literal: true

require "test_helper"

class ExplorationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    sign_in_as(@user)
  end

  # ===========================================
  # Show action
  # ===========================================

  test "show renders exploration page" do
    get exploration_path

    assert_response :success
    assert_select "h2", /Exploration/
  end

  # ===========================================
  # Growing arcs action
  # ===========================================

  test "growing_arcs explores closest unexplored coordinate" do
    assert_difference -> { ExploredCoordinate.count }, 1 do
      post growing_arcs_exploration_path
    end

    assert_redirected_to exploration_path
    assert_match /Explored/, flash[:notice]
  end

  test "growing_arcs shows alert when all coordinates explored" do
    # Mark all valid coordinates as explored
    ExplorationService::VALID_COORDS.each do |x|
      ExplorationService::VALID_COORDS.each do |y|
        ExplorationService::VALID_COORDS.each do |z|
          ExploredCoordinate.mark_explored!(user: @user, x: x, y: y, z: z)
        end
      end
    end

    post growing_arcs_exploration_path

    assert_redirected_to exploration_path
    assert_match /All coordinates explored/, flash[:alert]
  end

  # ===========================================
  # Orbit action
  # ===========================================

  test "orbit explores a new coordinate when unexplored exists" do
    # Use fresh user so we control the starting state
    fresh_user = User.create!(
      email: "orbit_test@example.com",
      name: "Orbit Tester",
      tutorial_phase: :proving_ground,
      profile_completed_at: Time.current
    )
    sign_in_as(fresh_user)

    assert_difference -> { fresh_user.explored_coordinates.count }, 1 do
      post orbit_exploration_path
    end

    assert_redirected_to exploration_path
    assert_match /Explored/, flash[:notice]
  end

  test "orbit explores coordinates from origin when no ship" do
    # Use a fresh user without ships
    fresh_user = User.create!(
      email: "shipless@example.com",
      name: "Shipless Explorer",
      tutorial_phase: :proving_ground,
      profile_completed_at: Time.current
    )
    sign_in_as(fresh_user)

    post orbit_exploration_path

    fresh_user.reload
    coord = fresh_user.explored_coordinates.order(created_at: :desc).first

    assert_not_nil coord, "Should have created an explored coordinate"
    # Should be at distance 0 (origin) since no ship
    assert_equal 0, coord.x
    assert_equal 0, coord.y
    assert_equal 0, coord.z
  end

  test "orbit expands to next ring when origin is explored" do
    # Use fresh user to avoid fixture ship positions
    fresh_user = User.create!(
      email: "orbital_ring@example.com",
      name: "Orbital Ring Tester",
      tutorial_phase: :proving_ground,
      profile_completed_at: Time.current
    )
    sign_in_as(fresh_user)

    # Mark origin as explored
    fresh_user.explored_coordinates.create!(x: 0, y: 0, z: 0, has_system: false)
    initial_count = fresh_user.explored_coordinates.count

    post orbit_exploration_path

    fresh_user.reload
    # Get the newly created coordinate (not origin)
    new_coords = fresh_user.explored_coordinates.where.not(x: 0, y: 0, z: 0)
    assert_equal 1, new_coords.count, "Should have created one new coordinate (not origin)"

    coord = new_coords.first
    # Should be at distance ~1 (next ring)
    distance = Math.sqrt(coord.x**2 + coord.y**2 + coord.z**2)
    assert_in_delta 1.0, distance, 0.5, "Should explore at distance ~1"
  end

  test "orbit records has_system when system exists at coordinate" do
    # Use fresh user to control state
    fresh_user = User.create!(
      email: "system_test@example.com",
      name: "System Tester",
      tutorial_phase: :proving_ground,
      profile_completed_at: Time.current
    )
    sign_in_as(fresh_user)

    # Clear any existing system at origin and create the Cradle
    System.where(x: 0, y: 0, z: 0).destroy_all
    System.cradle # Creates system at 0,0,0

    assert_difference -> { fresh_user.explored_coordinates.count }, 1 do
      post orbit_exploration_path
    end

    fresh_user.reload
    coord = fresh_user.explored_coordinates.find_by(x: 0, y: 0, z: 0)
    assert_not_nil coord, "Should have explored origin"
    assert coord.has_system, "Should record has_system as true when system exists"
  end

  test "orbit records has_system as false when no system at coordinate" do
    # Use fresh user to control state
    fresh_user = User.create!(
      email: "no_system_test@example.com",
      name: "No System Tester",
      tutorial_phase: :proving_ground,
      profile_completed_at: Time.current
    )
    sign_in_as(fresh_user)

    # Ensure no system at origin
    System.where(x: 0, y: 0, z: 0).destroy_all

    assert_difference -> { fresh_user.explored_coordinates.count }, 1 do
      post orbit_exploration_path
    end

    fresh_user.reload
    coord = fresh_user.explored_coordinates.find_by(x: 0, y: 0, z: 0)
    assert_not_nil coord, "Should have explored origin"
    assert_not coord.has_system, "Should record has_system as false when no system"
  end
end
