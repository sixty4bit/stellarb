# frozen_string_literal: true

require "test_helper"

class BuildingConstructionServiceTest < ActiveSupport::TestCase
  # Building construction is a Phase 2 (Proving Ground) mechanic
  # Players learn to construct their first asset (Mineral Extractor)

  setup do
    @user = User.create!(
      email: "builder@example.com",
      name: "Builder Test",
      tutorial_phase: :proving_ground,
      credits: 5000
    )
    # Discover Talos Prime - has minerals for building
    @system = System.discover_at(x: 1, y: 0, z: 0, user: @user)
    @ship = Ship.create!(
      user: @user,
      name: "Builder Ship",
      hull_size: "transport",
      race: "krog",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @system,
      cargo: { "iron" => 50, "silicon" => 30 }
    )
  end

  # Basic construction
  test "construct creates a building in under_construction status" do
    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    assert result.building.present?
    assert_equal "under_construction", result.building.status
    assert_equal @system, result.building.system
    assert_equal @user, result.building.user
  end

  test "construction requires sufficient credits" do
    @user.update!(credits: 0)

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert_not result.success?
    assert_match(/insufficient credits/i, result.error)
  end

  test "construction requires materials in ship cargo" do
    @ship.update!(cargo: {})

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert_not result.success?
    assert_match(/missing materials/i, result.error)
  end

  test "construction consumes credits and materials" do
    initial_credits = @user.credits
    initial_iron = @ship.cargo["iron"]

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    @user.reload
    @ship.reload

    assert @user.credits < initial_credits, "Should consume credits"
    assert @ship.cargo["iron"].to_i < initial_iron, "Should consume iron"
  end

  test "construction sets completion time" do
    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    assert result.building.construction_ends_at.present?
    assert result.building.construction_ends_at > Time.current
  end

  # Building types
  test "mineral_extractor is available for tutorial" do
    types = BuildingConstructionService.available_building_types(tutorial_phase: :proving_ground)

    assert types.include?(:mineral_extractor)
  end

  test "mineral_extractor has specific requirements" do
    requirements = BuildingConstructionService.requirements_for(:mineral_extractor)

    assert requirements[:credits] > 0
    assert requirements[:materials].present?
    assert requirements[:materials].key?(:iron)
    assert requirements[:construction_time] > 0
  end

  test "advanced buildings not available in proving_ground phase" do
    types = BuildingConstructionService.available_building_types(tutorial_phase: :proving_ground)

    assert_not types.include?(:defense_platform)
    assert_not types.include?(:refinery)
  end

  # Tutorial integration
  test "first building triggers tutorial milestone" do
    @user.update!(tutorial_phase: :proving_ground)
    assert_equal 0, @user.buildings.count

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    assert result.tutorial_milestone?
    assert_equal :first_building, result.tutorial_milestone
  end

  test "subsequent buildings do not trigger milestone" do
    # Create first building
    Building.create!(
      user: @user,
      system: @system,
      name: "Existing Mine",
      race: "krog",
      function: "extraction",
      tier: 1,
      status: "active"
    )

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    assert_not result.tutorial_milestone?
  end

  # Location requirements
  test "construction requires ship to be docked in target system" do
    other_system = System.discover_at(x: 0, y: 1, z: 0, user: @user)
    @ship.update!(current_system: other_system)

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert_not result.success?
    assert_match(/ship must be docked/i, result.error)
  end

  # Completion flow
  test "complete_construction transitions building to active" do
    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )
    building = result.building

    # Fast-forward construction time
    building.update!(construction_ends_at: 1.hour.ago)

    complete_result = BuildingConstructionService.complete_construction(building: building)

    assert complete_result.success?
    building.reload
    assert_equal "active", building.status
  end

  test "complete_construction fails if not finished" do
    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )
    building = result.building

    complete_result = BuildingConstructionService.complete_construction(building: building)

    assert_not complete_result.success?
    assert_match(/not finished/i, complete_result.error)
  end
end
