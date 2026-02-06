# frozen_string_literal: true

# Minerals constant defining all 60 minerals in StellArb.
# 50 real minerals (4 tiers) + 10 futuristic minerals.
#
# Reference: Source doc Section 1.1-1.2
module Minerals
  # Tier 1: Common (Starter Zone) - 10 minerals
  TIER_1_COMMON = [
    { name: "Iron", category: "Metal", base_price: 10, tier: :common, notes: "Foundation of all construction" },
    { name: "Copper", category: "Metal", base_price: 15, tier: :common, notes: "Electronics, wiring" },
    { name: "Aluminum", category: "Metal", base_price: 12, tier: :common, notes: "Lightweight structures" },
    { name: "Silicon", category: "Semiconductor", base_price: 18, tier: :common, notes: "Electronics base" },
    { name: "Carbon", category: "Element", base_price: 8, tier: :common, notes: "Alloys, fuel" },
    { name: "Sulfur", category: "Element", base_price: 6, tier: :common, notes: "Chemicals, fuel" },
    { name: "Limestoneite", category: "Rock", base_price: 5, tier: :common, notes: "Construction" },
    { name: "Salt", category: "Mineral", base_price: 4, tier: :common, notes: "Chemicals, preservation" },
    { name: "Coal", category: "Fuel", base_price: 7, tier: :common, notes: "Energy, carbon source" },
    { name: "Graphite", category: "Carbon", base_price: 14, tier: :common, notes: "Lubricants, batteries" }
  ].freeze

  # Tier 2: Uncommon (Mid-range) - 15 minerals
  TIER_2_UNCOMMON = [
    { name: "Nickel", category: "Metal", base_price: 25, tier: :uncommon, notes: "Alloys, batteries" },
    { name: "Zinc", category: "Metal", base_price: 22, tier: :uncommon, notes: "Alloys, corrosion resistance" },
    { name: "Tin", category: "Metal", base_price: 28, tier: :uncommon, notes: "Soldering, alloys" },
    { name: "Lead", category: "Metal", base_price: 20, tier: :uncommon, notes: "Radiation shielding" },
    { name: "Manganese", category: "Metal", base_price: 30, tier: :uncommon, notes: "Steel production" },
    { name: "Chromium", category: "Metal", base_price: 35, tier: :uncommon, notes: "Stainless steel" },
    { name: "Cobalt", category: "Metal", base_price: 45, tier: :uncommon, notes: "Batteries, magnets" },
    { name: "Tungsten", category: "Metal", base_price: 55, tier: :uncommon, notes: "High-temp applications" },
    { name: "Molybdenum", category: "Metal", base_price: 50, tier: :uncommon, notes: "Steel strengthening" },
    { name: "Vanadium", category: "Metal", base_price: 48, tier: :uncommon, notes: "Steel alloys" },
    { name: "Quartz", category: "Crystal", base_price: 32, tier: :uncommon, notes: "Electronics, optics" },
    { name: "Feldspar", category: "Mineral", base_price: 15, tier: :uncommon, notes: "Ceramics" },
    { name: "Mica", category: "Mineral", base_price: 25, tier: :uncommon, notes: "Insulation" },
    { name: "Bauxite", category: "Ore", base_price: 18, tier: :uncommon, notes: "Aluminum source" },
    { name: "Magnetite", category: "Ore", base_price: 22, tier: :uncommon, notes: "Iron source, magnets" }
  ].freeze

  # Tier 3: Rare (Deep Space) - 15 minerals
  TIER_3_RARE = [
    { name: "Gold", category: "Precious", base_price: 100, tier: :rare, notes: "Electronics, currency" },
    { name: "Silver", category: "Precious", base_price: 65, tier: :rare, notes: "Electronics, conductivity" },
    { name: "Platinum", category: "Precious", base_price: 150, tier: :rare, notes: "Catalysts, electronics" },
    { name: "Palladium", category: "Precious", base_price: 140, tier: :rare, notes: "Catalysts" },
    { name: "Rhodium", category: "Precious", base_price: 200, tier: :rare, notes: "Catalysts, reflectors" },
    { name: "Titanium", category: "Metal", base_price: 80, tier: :rare, notes: "Aerospace, strength" },
    { name: "Lithium", category: "Alkali", base_price: 75, tier: :rare, notes: "Batteries" },
    { name: "Beryllium", category: "Metal", base_price: 90, tier: :rare, notes: "Aerospace alloys" },
    { name: "Tantalum", category: "Metal", base_price: 120, tier: :rare, notes: "Capacitors" },
    { name: "Niobium", category: "Metal", base_price: 95, tier: :rare, notes: "Superconductors" },
    { name: "Gallium", category: "Metal", base_price: 85, tier: :rare, notes: "Semiconductors" },
    { name: "Germanium", category: "Semiconductor", base_price: 110, tier: :rare, notes: "Electronics" },
    { name: "Indium", category: "Metal", base_price: 130, tier: :rare, notes: "Displays, solar" },
    { name: "Tellurium", category: "Metalloid", base_price: 105, tier: :rare, notes: "Solar cells" },
    { name: "Neodymium", category: "Rare Earth", base_price: 160, tier: :rare, notes: "Magnets" }
  ].freeze

  # Tier 4: Exotic (Dangerous Zones) - 10 minerals
  TIER_4_EXOTIC = [
    { name: "Uranium", category: "Radioactive", base_price: 250, tier: :exotic, notes: "Nuclear power" },
    { name: "Thorium", category: "Radioactive", base_price: 220, tier: :exotic, notes: "Nuclear alternative" },
    { name: "Plutonium", category: "Radioactive", base_price: 400, tier: :exotic, notes: "Advanced reactors" },
    { name: "Iridium", category: "Precious", base_price: 300, tier: :exotic, notes: "Extreme durability" },
    { name: "Osmium", category: "Precious", base_price: 280, tier: :exotic, notes: "Densest material" },
    { name: "Rhenium", category: "Metal", base_price: 350, tier: :exotic, notes: "High-temp alloys" },
    { name: "Scandium", category: "Rare Earth", base_price: 180, tier: :exotic, notes: "Aerospace alloys" },
    { name: "Yttrium", category: "Rare Earth", base_price: 170, tier: :exotic, notes: "Lasers, superconductors" },
    { name: "Hafnium", category: "Metal", base_price: 260, tier: :exotic, notes: "Nuclear control rods" },
    { name: "Zirconium", category: "Metal", base_price: 145, tier: :exotic, notes: "Nuclear, ceramics" }
  ].freeze

  # Futuristic Minerals (10) - Exclusive to StellArb, found in specific system types
  FUTURISTIC = [
    { name: "Stellarium", category: "Futuristic", base_price: 500, tier: :futuristic, found_in: "Neutron Stars", notes: "Ultra-dense, FTL components" },
    { name: "Voidite", category: "Futuristic", base_price: 750, tier: :futuristic, found_in: "Black Hole Proximity", notes: "Gravity manipulation" },
    { name: "Chronite", category: "Futuristic", base_price: 600, tier: :futuristic, found_in: "Binary Systems", notes: "Temporal stability circuits" },
    { name: "Plasmaite", category: "Futuristic", base_price: 450, tier: :futuristic, found_in: "Blue Giants", notes: "Plasma containment" },
    { name: "Darkstone", category: "Futuristic", base_price: 800, tier: :futuristic, found_in: "Deep Space (>5000 units)", notes: "Stealth technology" },
    { name: "Quantium", category: "Futuristic", base_price: 650, tier: :futuristic, found_in: "Pulsars", notes: "Quantum computing" },
    { name: "Nebulite", category: "Futuristic", base_price: 400, tier: :futuristic, found_in: "Nebulae", notes: "Shield harmonics" },
    { name: "Solarite", category: "Futuristic", base_price: 350, tier: :futuristic, found_in: "Yellow Giants", notes: "Solar efficiency" },
    { name: "Cryonite", category: "Futuristic", base_price: 300, tier: :futuristic, found_in: "Ice Giants", notes: "Cryo-storage" },
    { name: "Exotite", category: "Futuristic", base_price: 1000, tier: :futuristic, found_in: "Anomalies", notes: "Unknown properties, research" }
  ].freeze

  # All 60 minerals combined
  ALL = (TIER_1_COMMON + TIER_2_UNCOMMON + TIER_3_RARE + TIER_4_EXOTIC + FUTURISTIC).freeze

  # Index for fast lookup by name (case-insensitive)
  BY_NAME = ALL.each_with_object({}) { |m, h| h[m[:name].downcase] = m }.freeze

  # Index by tier
  BY_TIER = ALL.group_by { |m| m[:tier] }.freeze

  class << self
    # Find a mineral by name (case-insensitive)
    # @param name [String] Mineral name
    # @return [Hash, nil] Mineral data or nil if not found
    def find(name)
      BY_NAME[name.to_s.downcase]
    end

    # Get all minerals for a tier
    # @param tier [Symbol] :common, :uncommon, :rare, :exotic, or :futuristic
    # @return [Array<Hash>] Minerals in that tier
    def by_tier(tier)
      BY_TIER[tier] || []
    end

    # Get all mineral names
    # @return [Array<String>] List of mineral names
    def names
      ALL.map { |m| m[:name] }
    end

    # Get all real minerals (non-futuristic)
    # @return [Array<Hash>] Real minerals
    def real
      ALL.reject { |m| m[:tier] == :futuristic }
    end

    # Get all futuristic minerals
    # @return [Array<Hash>] Futuristic minerals
    def futuristic
      BY_TIER[:futuristic] || []
    end
  end
end
