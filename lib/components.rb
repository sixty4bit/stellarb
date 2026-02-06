# frozen_string_literal: true

require "minerals"

# Components constant defining all craftable components in StellArb.
# Components are produced by NPC factories and traded by players.
# Prices are derived from input mineral costs × 1.5 manufacturing margin.
#
# Reference: Source doc Section 2.1-2.2
module Components
  # The 9 component categories
  CATEGORIES = [
    "Basic Parts",
    "Electronics",
    "Structural",
    "Power",
    "Propulsion",
    "Weapons",
    "Defense",
    "Life Support",
    "Advanced"
  ].freeze

  # Basic Parts - Foundation components from Tier 1 minerals
  # Primary inputs: Iron, Copper, Carbon (Tier 1)
  BASIC_PARTS = [
    { name: "Iron Plate", category: "Basic Parts", inputs: { "Iron" => 2 } },
    { name: "Copper Wire", category: "Basic Parts", inputs: { "Copper" => 1, "Carbon" => 1 } },
    { name: "Steel Beam", category: "Basic Parts", inputs: { "Iron" => 3, "Carbon" => 1 } },
    { name: "Metal Bracket", category: "Basic Parts", inputs: { "Iron" => 1, "Aluminum" => 1 } },
    { name: "Carbon Rod", category: "Basic Parts", inputs: { "Carbon" => 2, "Graphite" => 1 } }
  ].freeze

  # Electronics - Circuit components
  # Primary inputs: Silicon, Copper, Gold
  ELECTRONICS = [
    { name: "Circuit Board", category: "Electronics", inputs: { "Silicon" => 2, "Copper" => 1 } },
    { name: "Processor", category: "Electronics", inputs: { "Silicon" => 3, "Gold" => 1, "Copper" => 1 } },
    { name: "Sensor", category: "Electronics", inputs: { "Silicon" => 1, "Copper" => 1, "Quartz" => 1 } },
    { name: "Memory Core", category: "Electronics", inputs: { "Silicon" => 2, "Gold" => 1 } },
    { name: "Power Regulator", category: "Electronics", inputs: { "Copper" => 2, "Silicon" => 1, "Germanium" => 1 } }
  ].freeze

  # Structural - Hull and frame components
  # Primary inputs: Iron, Titanium, Carbon
  STRUCTURAL = [
    { name: "Hull Plating", category: "Structural", inputs: { "Iron" => 3, "Titanium" => 1 } },
    { name: "Bulkhead", category: "Structural", inputs: { "Iron" => 2, "Carbon" => 2 } },
    { name: "Frame Section", category: "Structural", inputs: { "Titanium" => 2, "Carbon" => 1 } },
    { name: "Reinforced Panel", category: "Structural", inputs: { "Iron" => 2, "Titanium" => 1, "Carbon" => 1 } },
    { name: "Pressure Seal", category: "Structural", inputs: { "Titanium" => 1, "Carbon" => 2 } }
  ].freeze

  # Power - Energy storage and generation
  # Primary inputs: Lithium, Uranium, Silicon, Cobalt
  POWER = [
    { name: "Battery", category: "Power", inputs: { "Lithium" => 2, "Cobalt" => 1 } },
    { name: "Fusion Cell", category: "Power", inputs: { "Uranium" => 1, "Lithium" => 1, "Cobalt" => 1 } },
    { name: "Solar Panel", category: "Power", inputs: { "Silicon" => 2, "Indium" => 1 } },
    { name: "Power Conduit", category: "Power", inputs: { "Copper" => 2, "Silver" => 1 } },
    { name: "Reactor Core", category: "Power", inputs: { "Uranium" => 2, "Hafnium" => 1, "Zirconium" => 1 } }
  ].freeze

  # Propulsion - Engine and FTL components
  # Primary inputs: Titanium, Stellarium
  PROPULSION = [
    { name: "Thruster", category: "Propulsion", inputs: { "Titanium" => 2, "Tungsten" => 1 } },
    { name: "Engine Core", category: "Propulsion", inputs: { "Titanium" => 3, "Cobalt" => 1, "Manganese" => 1 } },
    { name: "FTL Coil", category: "Propulsion", inputs: { "Stellarium" => 2, "Titanium" => 1 } },
    { name: "Fuel Injector", category: "Propulsion", inputs: { "Titanium" => 1, "Tungsten" => 1, "Chromium" => 1 } },
    { name: "Nav Computer", category: "Propulsion", inputs: { "Silicon" => 2, "Chronite" => 1 } }
  ].freeze

  # Weapons - Offensive systems
  # Primary inputs: Tungsten, Platinum
  WEAPONS = [
    { name: "Laser Lens", category: "Weapons", inputs: { "Quartz" => 2, "Platinum" => 1 } },
    { name: "Missile Casing", category: "Weapons", inputs: { "Tungsten" => 2, "Titanium" => 1 } },
    { name: "Railgun Barrel", category: "Weapons", inputs: { "Tungsten" => 3, "Manganese" => 1 } },
    { name: "Plasma Chamber", category: "Weapons", inputs: { "Tungsten" => 2, "Plasmaite" => 1 } },
    { name: "Targeting Array", category: "Weapons", inputs: { "Platinum" => 1, "Gold" => 1, "Silicon" => 1 } }
  ].freeze

  # Defense - Shields and armor
  # Primary inputs: Titanium, Nebulite
  DEFENSE = [
    { name: "Shield Emitter", category: "Defense", inputs: { "Titanium" => 2, "Nebulite" => 1 } },
    { name: "Armor Plate", category: "Defense", inputs: { "Titanium" => 3, "Iridium" => 1 } },
    { name: "Deflector Array", category: "Defense", inputs: { "Nebulite" => 2, "Silver" => 1 } },
    { name: "Point Defense", category: "Defense", inputs: { "Titanium" => 1, "Tungsten" => 1, "Silicon" => 1 } },
    { name: "Stealth Plating", category: "Defense", inputs: { "Darkstone" => 2, "Carbon" => 2 } }
  ].freeze

  # Life Support - Crew survival systems
  # Primary inputs: Aluminum, Carbon
  LIFE_SUPPORT = [
    { name: "Air Recycler", category: "Life Support", inputs: { "Aluminum" => 2, "Carbon" => 2 } },
    { name: "Water Purifier", category: "Life Support", inputs: { "Aluminum" => 1, "Carbon" => 1, "Salt" => 1 } },
    { name: "Cryo Pod", category: "Life Support", inputs: { "Aluminum" => 2, "Cryonite" => 1 } },
    { name: "Atmospheric Processor", category: "Life Support", inputs: { "Carbon" => 3, "Aluminum" => 1 } },
    { name: "Radiation Filter", category: "Life Support", inputs: { "Lead" => 2, "Aluminum" => 1 } }
  ].freeze

  # Advanced - High-tech components from futuristic minerals
  # Primary inputs: Various futuristic minerals
  ADVANCED = [
    { name: "Quantum Core", category: "Advanced", inputs: { "Quantium" => 2, "Gold" => 1 } },
    { name: "Gravity Generator", category: "Advanced", inputs: { "Voidite" => 2, "Titanium" => 1 } },
    { name: "Temporal Stabilizer", category: "Advanced", inputs: { "Chronite" => 2, "Platinum" => 1 } },
    { name: "Dark Matter Container", category: "Advanced", inputs: { "Darkstone" => 2, "Stellarium" => 1 } },
    { name: "Exo-Research Module", category: "Advanced", inputs: { "Exotite" => 1, "Quantium" => 1, "Silicon" => 2 } }
  ].freeze

  # All components combined
  ALL = (
    BASIC_PARTS +
    ELECTRONICS +
    STRUCTURAL +
    POWER +
    PROPULSION +
    WEAPONS +
    DEFENSE +
    LIFE_SUPPORT +
    ADVANCED
  ).freeze

  # Index for fast lookup by name (case-insensitive)
  BY_NAME = ALL.each_with_object({}) { |c, h| h[c[:name].downcase] = c }.freeze

  # Index by category
  BY_CATEGORY = ALL.group_by { |c| c[:category] }.freeze

  class << self
    # Find a component by name (case-insensitive)
    # @param name [String] Component name
    # @return [Hash, nil] Component data or nil if not found
    def find(name)
      BY_NAME[name.to_s.downcase]
    end

    # Get all components for a category
    # @param category [String] Category name (e.g., "Basic Parts", "Electronics")
    # @return [Array<Hash>] Components in that category
    def by_category(category)
      BY_CATEGORY[category] || []
    end

    # Calculate base price for a component
    # Price = (Sum of Input Mineral Prices) × 1.5
    # @param component [Hash, String] Component data hash or name
    # @return [Integer] Base price in credits
    def base_price(component)
      component = find(component) if component.is_a?(String)
      return nil unless component

      input_cost = component[:inputs].sum do |mineral_name, quantity|
        mineral = Minerals.find(mineral_name)
        raise "Unknown mineral: #{mineral_name}" unless mineral
        mineral[:base_price] * quantity
      end

      (input_cost * 1.5).round
    end

    # Get all component names
    # @return [Array<String>] List of component names
    def names
      ALL.map { |c| c[:name] }
    end

    # Get components that use a specific mineral as input
    # @param mineral_name [String] Mineral name
    # @return [Array<Hash>] Components using that mineral
    def using_mineral(mineral_name)
      ALL.select { |c| c[:inputs].key?(mineral_name) }
    end
  end
end
