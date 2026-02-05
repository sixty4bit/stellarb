# frozen_string_literal: true

require "test_helper"

class ReservedSystemTest < ActiveSupport::TestCase
  # The "Talos Arm" - reserved systems adjacent to The Cradle for tutorial
  # These are the first systems players explore in Phase 2: Proving Ground

  test "TALOS_ARM contains exactly 6 reserved systems" do
    assert_equal 6, ProceduralGeneration::ReservedSystem::TALOS_ARM.length
  end

  test "all Talos Arm systems are within 3 units of The Cradle" do
    ProceduralGeneration::ReservedSystem::TALOS_ARM.each do |coords|
      distance = Math.sqrt(coords[:x]**2 + coords[:y]**2 + coords[:z]**2)
      assert distance <= 3.5, "System at #{coords} is #{distance} units from Cradle (max 3.5)"
    end
  end

  test "generates deterministic reserved system properties" do
    system1 = ProceduralGeneration::ReservedSystem.generate(1, 1, 1)
    system2 = ProceduralGeneration::ReservedSystem.generate(1, 1, 1)

    assert_equal system1, system2, "Same coordinates should produce identical systems"
  end

  test "reserved system has tutorial-friendly properties" do
    system = ProceduralGeneration::ReservedSystem.generate(1, 1, 1)

    assert system[:name].present?, "Should have a name"
    assert system[:hazard_level] <= 10, "Hazard level should be low for tutorial (max 10)"
    assert system[:is_reserved], "Should be marked as reserved"
    assert system[:tutorial_eligible], "Should be tutorial eligible"
    assert system[:planet_count] >= 2, "Should have at least 2 planets for building tutorial"
  end

  test "reserved systems have mineral deposits for first building" do
    system = ProceduralGeneration::ReservedSystem.generate(1, 1, 1)

    minerals = system[:mineral_distribution].values.flat_map { |p| p[:minerals] }
    assert minerals.include?("iron"), "Should have iron for basic construction"
    assert minerals.include?("silicon"), "Should have silicon for basic construction"
  end

  test "each Talos Arm system has unique properties" do
    systems = ProceduralGeneration::ReservedSystem::TALOS_ARM.map do |coords|
      ProceduralGeneration::ReservedSystem.generate(coords[:x], coords[:y], coords[:z])
    end

    names = systems.map { |s| s[:name] }
    assert_equal names.uniq.length, names.length, "All reserved systems should have unique names"
  end

  test "reserved system at (1,0,0) is Talos Prime - the tutorial target" do
    system = ProceduralGeneration::ReservedSystem.generate(1, 0, 0)

    assert_equal "Talos Prime", system[:name]
    assert system[:is_primary_tutorial], "Should be marked as primary tutorial system"
    assert system[:hazard_level] == 0, "Primary tutorial system should have zero hazard"
  end

  test "User#available_proving_ground_systems returns Talos Arm for users in proving_ground phase" do
    user = User.create!(
      email: "proving_ground_test@example.com",
      name: "Test User",
      tutorial_phase: :proving_ground
    )

    available = user.available_proving_ground_systems

    assert_equal 6, available.length
    assert available.all? { |s| s[:is_reserved] }
  end

  test "User in cradle phase cannot access proving ground systems" do
    user = User.create!(
      email: "cradle_test@example.com",
      name: "Test User",
      tutorial_phase: :cradle
    )

    available = user.available_proving_ground_systems

    assert_empty available
  end
end
