# frozen_string_literal: true

require 'digest'

module ProceduralGeneration
  STAR_TYPES = %w[
    red_dwarf yellow_dwarf orange_dwarf white_dwarf
    blue_giant red_giant yellow_giant
    neutron_star binary_system black_hole_proximity
  ].freeze

  # Extract value from seed hex string
  # @param seed_hex [String] 64-character hex string (256 bits)
  # @param byte_offset [Integer] Starting byte position
  # @param byte_length [Integer] Number of bytes to extract
  # @param max_value [Integer] Maximum value (used for modulo)
  # @return [Integer] Extracted value between 0 and max_value-1
  def self.extract_from_seed(seed_hex, byte_offset, byte_length, max_value)
    # seed_hex is 64 chars (256 bits), each char = 4 bits, each byte = 2 chars
    slice = seed_hex[byte_offset * 2, byte_length * 2]
    slice.to_i(16) % max_value
  end

  # Generate a system from coordinates
  # @param x [Integer] X coordinate (0..999_999)
  # @param y [Integer] Y coordinate (0..999_999)
  # @param z [Integer] Z coordinate (0..999_999)
  # @return [Hash] System properties
  def self.generate_system(x, y, z)
    # Special case for The Cradle
    if x == 0 && y == 0 && z == 0
      return generate_cradle
    end

    # Generate deterministic seed
    seed = Digest::SHA256.hexdigest("#{x}|#{y}|#{z}")

    # Extract system properties from seed (non-overlapping byte allocations)
    star_type_idx  = extract_from_seed(seed, 0, 2, STAR_TYPES.length)  # bytes 0-1
    planet_count   = extract_from_seed(seed, 2, 1, 13)                  # byte 2 (0-12)
    hazard_level   = extract_from_seed(seed, 3, 1, 101)                 # byte 3 (0-100)
    mineral_seed   = extract_from_seed(seed, 4, 4, 2**32)               # bytes 4-7
    price_seed     = extract_from_seed(seed, 8, 4, 2**32)               # bytes 8-11
    name_seed      = extract_from_seed(seed, 12, 4, 2**32)              # bytes 12-15

    {
      coordinates: { x: x, y: y, z: z },
      seed: seed,
      name: generate_system_name(name_seed),
      star_type: STAR_TYPES[star_type_idx],
      planet_count: planet_count,
      hazard_level: hazard_level,
      mineral_distribution: generate_mineral_distribution(mineral_seed, planet_count),
      base_prices: generate_base_prices(price_seed),
      discovered: false,
      discovered_by: nil,
      discovery_date: nil
    }
  end

  # Generate The Cradle (tutorial system at 0,0,0)
  def self.generate_cradle
    {
      coordinates: { x: 0, y: 0, z: 0 },
      seed: "cradle_fixed_seed",
      name: "The Cradle",
      star_type: "yellow_dwarf",
      planet_count: 5,
      hazard_level: 0,
      mineral_distribution: {
        0 => { minerals: %w[iron copper], abundance: :high },
        1 => { minerals: %w[water ice], abundance: :high },
        2 => { minerals: %w[silicon aluminum], abundance: :medium },
        3 => { minerals: %w[gold silver], abundance: :low },
        4 => { minerals: %w[uranium plutonium], abundance: :very_low }
      },
      base_prices: {
        iron: 10,
        copper: 15,
        water: 5,
        food: 20,
        fuel: 30,
        luxury_goods: 100
      },
      discovered: true,
      discovered_by: "System",
      discovery_date: Time.current,
      special_properties: {
        tutorial_zone: true,
        high_security: true,
        saturated_markets: true
      }
    }
  end

  # Generate a procedural system name
  def self.generate_system_name(seed)
    prefixes = %w[Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa]
    middles = %w[Centauri Pegasi Cygni Orionis Ursae Draconis Leonis Aquarii Scorpii Tauri]
    suffixes = %w[Prime Major Minor Alpha Beta Gamma I II III IV V VI VII VIII IX X]

    prefix_idx = seed % prefixes.length
    middle_idx = (seed / prefixes.length) % middles.length
    suffix_idx = (seed / (prefixes.length * middles.length)) % suffixes.length

    "#{prefixes[prefix_idx]} #{middles[middle_idx]} #{suffixes[suffix_idx]}"
  end

  # Generate mineral distribution for planets
  def self.generate_mineral_distribution(seed, planet_count)
    minerals = %w[iron copper gold silver uranium plutonium silicon aluminum titanium platinum water ice hydrogen helium]
    distribution = {}

    planet_count.times do |planet_idx|
      planet_seed = seed + planet_idx
      mineral_count = (planet_seed % 3) + 1 # 1-3 minerals per planet

      planet_minerals = []
      mineral_count.times do |i|
        mineral_idx = (planet_seed + i * 1000) % minerals.length
        planet_minerals << minerals[mineral_idx]
      end

      abundance = case planet_seed % 4
                  when 0 then :low
                  when 1 then :medium
                  when 2 then :high
                  else :very_high
                  end

      distribution[planet_idx] = {
        minerals: planet_minerals.uniq,
        abundance: abundance
      }
    end

    distribution
  end

  # Generate base prices for common commodities
  def self.generate_base_prices(seed)
    # Base prices with some variance based on seed
    commodities = {
      # Basic resources
      iron: 10 + (seed % 5),
      copper: 15 + (seed % 7),
      gold: 100 + (seed % 30),
      silver: 50 + (seed % 20),
      water: 5 + (seed % 3),

      # Processed goods
      steel: 25 + (seed % 10),
      electronics: 75 + (seed % 25),
      chemicals: 40 + (seed % 15),

      # Consumer goods
      food: 20 + (seed % 8),
      luxury_goods: 200 + (seed % 50),
      medicine: 150 + (seed % 40),

      # Energy
      fuel: 30 + (seed % 12),
      batteries: 60 + (seed % 20),

      # Special
      weapons: 300 + (seed % 100),
      ship_parts: 250 + (seed % 80)
    }

    # Apply system-wide price modifier
    price_modifier = 0.5 + (seed % 150) / 100.0 # 0.5 to 2.0

    commodities.transform_values { |price| (price * price_modifier).round }
  end
end