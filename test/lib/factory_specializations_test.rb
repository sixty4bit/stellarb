# frozen_string_literal: true

require "test_helper"
require "factory_specializations"

class FactorySpecializationsTest < ActiveSupport::TestCase
  # ===========================================
  # Structure Tests
  # ===========================================

  test "defines exactly 8 specializations" do
    assert_equal 8, FactorySpecializations::ALL.keys.size
  end

  test "includes all required specialization names" do
    expected = %w[basic electronics structural power propulsion weapons defense advanced]

    expected.each do |name|
      assert_includes FactorySpecializations::ALL.keys, name,
        "Missing specialization: #{name}"
    end
  end

  test "each specialization has consume and produce lists" do
    FactorySpecializations::ALL.each do |name, config|
      assert config[:consume].is_a?(Array), "#{name} missing consume array"
      assert config[:produce].is_a?(Array), "#{name} missing produce array"
      assert config[:consume].any?, "#{name} has empty consume list"
      assert config[:produce].any?, "#{name} has empty produce list"
    end
  end

  # ===========================================
  # Lookup Tests
  # ===========================================

  test "find returns specialization by name" do
    spec = FactorySpecializations.find("basic")

    assert_not_nil spec
    assert spec[:consume].any?
    assert spec[:produce].any?
  end

  test "find is case-insensitive" do
    assert_equal FactorySpecializations.find("BASIC"), FactorySpecializations.find("basic")
    assert_equal FactorySpecializations.find("Electronics"), FactorySpecializations.find("electronics")
  end

  test "find returns nil for unknown specialization" do
    assert_nil FactorySpecializations.find("nonexistent")
    assert_nil FactorySpecializations.find("")
    assert_nil FactorySpecializations.find(nil)
  end

  test "names returns all specialization names" do
    names = FactorySpecializations.names

    assert_equal 8, names.size
    assert_includes names, "basic"
    assert_includes names, "advanced"
  end

  # ===========================================
  # Consume/Produce Accessor Tests
  # ===========================================

  test "consumes returns input minerals for specialization" do
    inputs = FactorySpecializations.consumes("basic")

    assert inputs.is_a?(Array)
    assert inputs.any?
    # Basic consumes tier 1 minerals
    assert_includes inputs, "Iron"
    assert_includes inputs, "Copper"
  end

  test "produces returns output components for specialization" do
    outputs = FactorySpecializations.produces("basic")

    assert outputs.is_a?(Array)
    assert outputs.any?
    # Basic produces plates, wire, beams
    assert_includes outputs, "Iron Plate"
    assert_includes outputs, "Copper Wire"
    assert_includes outputs, "Steel Beam"
  end

  test "consumes returns empty array for unknown specialization" do
    assert_equal [], FactorySpecializations.consumes("nonexistent")
  end

  test "produces returns empty array for unknown specialization" do
    assert_equal [], FactorySpecializations.produces("nonexistent")
  end

  # ===========================================
  # Basic Specialization
  # ===========================================

  test "basic specialization consumes tier 1 minerals" do
    inputs = FactorySpecializations.consumes("basic")

    assert_includes inputs, "Iron"
    assert_includes inputs, "Copper"
    assert_includes inputs, "Carbon"
    assert_includes inputs, "Aluminum"
  end

  test "basic specialization produces basic parts components" do
    outputs = FactorySpecializations.produces("basic")

    # From Components::BASIC_PARTS
    assert_includes outputs, "Iron Plate"
    assert_includes outputs, "Copper Wire"
    assert_includes outputs, "Steel Beam"
    assert_includes outputs, "Metal Bracket"
    assert_includes outputs, "Carbon Rod"
  end

  # ===========================================
  # Electronics Specialization
  # ===========================================

  test "electronics specialization consumes silicon, copper, gold" do
    inputs = FactorySpecializations.consumes("electronics")

    assert_includes inputs, "Silicon"
    assert_includes inputs, "Copper"
    assert_includes inputs, "Gold"
  end

  test "electronics specialization produces electronics components" do
    outputs = FactorySpecializations.produces("electronics")

    # From Components::ELECTRONICS
    assert_includes outputs, "Circuit Board"
    assert_includes outputs, "Processor"
    assert_includes outputs, "Sensor"
    assert_includes outputs, "Memory Core"
    assert_includes outputs, "Power Regulator"
  end

  # ===========================================
  # Structural Specialization
  # ===========================================

  test "structural specialization consumes iron, titanium, carbon" do
    inputs = FactorySpecializations.consumes("structural")

    assert_includes inputs, "Iron"
    assert_includes inputs, "Titanium"
    assert_includes inputs, "Carbon"
  end

  test "structural specialization produces structural components" do
    outputs = FactorySpecializations.produces("structural")

    # From Components::STRUCTURAL
    assert_includes outputs, "Hull Plating"
    assert_includes outputs, "Bulkhead"
    assert_includes outputs, "Frame Section"
    assert_includes outputs, "Reinforced Panel"
    assert_includes outputs, "Pressure Seal"
  end

  # ===========================================
  # Power Specialization
  # ===========================================

  test "power specialization consumes lithium, uranium, cobalt" do
    inputs = FactorySpecializations.consumes("power")

    assert_includes inputs, "Lithium"
    assert_includes inputs, "Uranium"
    assert_includes inputs, "Cobalt"
  end

  test "power specialization produces power components" do
    outputs = FactorySpecializations.produces("power")

    # From Components::POWER
    assert_includes outputs, "Battery"
    assert_includes outputs, "Fusion Cell"
    assert_includes outputs, "Solar Panel"
    assert_includes outputs, "Power Conduit"
    assert_includes outputs, "Reactor Core"
  end

  # ===========================================
  # Propulsion Specialization
  # ===========================================

  test "propulsion specialization consumes titanium, tungsten, stellarium" do
    inputs = FactorySpecializations.consumes("propulsion")

    assert_includes inputs, "Titanium"
    assert_includes inputs, "Tungsten"
  end

  test "propulsion specialization produces propulsion components" do
    outputs = FactorySpecializations.produces("propulsion")

    # From Components::PROPULSION
    assert_includes outputs, "Thruster"
    assert_includes outputs, "Engine Core"
    assert_includes outputs, "FTL Coil"
    assert_includes outputs, "Fuel Injector"
    assert_includes outputs, "Nav Computer"
  end

  # ===========================================
  # Weapons Specialization
  # ===========================================

  test "weapons specialization consumes tungsten, platinum, quartz" do
    inputs = FactorySpecializations.consumes("weapons")

    assert_includes inputs, "Tungsten"
    assert_includes inputs, "Platinum"
    assert_includes inputs, "Quartz"
  end

  test "weapons specialization produces weapons components" do
    outputs = FactorySpecializations.produces("weapons")

    # From Components::WEAPONS
    assert_includes outputs, "Laser Lens"
    assert_includes outputs, "Missile Casing"
    assert_includes outputs, "Railgun Barrel"
    assert_includes outputs, "Plasma Chamber"
    assert_includes outputs, "Targeting Array"
  end

  # ===========================================
  # Defense Specialization
  # ===========================================

  test "defense specialization consumes titanium, nebulite, iridium" do
    inputs = FactorySpecializations.consumes("defense")

    assert_includes inputs, "Titanium"
    assert_includes inputs, "Nebulite"
    assert_includes inputs, "Iridium"
  end

  test "defense specialization produces defense components" do
    outputs = FactorySpecializations.produces("defense")

    # From Components::DEFENSE
    assert_includes outputs, "Shield Emitter"
    assert_includes outputs, "Armor Plate"
    assert_includes outputs, "Deflector Array"
    assert_includes outputs, "Point Defense"
    assert_includes outputs, "Stealth Plating"
  end

  # ===========================================
  # Advanced Specialization
  # ===========================================

  test "advanced specialization consumes futuristic minerals" do
    inputs = FactorySpecializations.consumes("advanced")

    # Futuristic minerals from Components::ADVANCED inputs
    assert_includes inputs, "Quantium"
    assert_includes inputs, "Voidite"
    assert_includes inputs, "Chronite"
  end

  test "advanced specialization produces advanced components" do
    outputs = FactorySpecializations.produces("advanced")

    # From Components::ADVANCED
    assert_includes outputs, "Quantum Core"
    assert_includes outputs, "Gravity Generator"
    assert_includes outputs, "Temporal Stabilizer"
    assert_includes outputs, "Dark Matter Container"
    assert_includes outputs, "Exo-Research Module"
  end

  # ===========================================
  # Component Validation
  # ===========================================

  test "all produced components exist in Components module" do
    FactorySpecializations::ALL.each do |name, config|
      config[:produce].each do |component_name|
        component = Components.find(component_name)
        assert_not_nil component,
          "#{name} produces unknown component: #{component_name}"
      end
    end
  end

  test "all consumed minerals exist in Minerals module" do
    FactorySpecializations::ALL.each do |name, config|
      config[:consume].each do |mineral_name|
        mineral = Minerals.find(mineral_name)
        assert_not_nil mineral,
          "#{name} consumes unknown mineral: #{mineral_name}"
      end
    end
  end

  # ===========================================
  # Reverse Lookup Tests
  # ===========================================

  test "specialization_for_component returns specialization that produces it" do
    spec = FactorySpecializations.specialization_for_component("Circuit Board")

    assert_equal "electronics", spec
  end

  test "specialization_for_component is case-insensitive" do
    assert_equal "electronics", FactorySpecializations.specialization_for_component("circuit board")
    assert_equal "electronics", FactorySpecializations.specialization_for_component("CIRCUIT BOARD")
  end

  test "specialization_for_component returns nil for unknown component" do
    assert_nil FactorySpecializations.specialization_for_component("Unknown Component")
  end
end
