# frozen_string_literal: true

require 'digest'

module ProceduralGeneration
  class ShipGenerator
    HULL_SIZES = {
      scout:     { cargo: 10,   fuel_eff: 1.0, crew: 1..2,  hardpoints: 1 },
      frigate:   { cargo: 50,   fuel_eff: 1.2, crew: 2..4,  hardpoints: 2 },
      transport: { cargo: 200,  fuel_eff: 1.5, crew: 3..6,  hardpoints: 2 },
      cruiser:   { cargo: 500,  fuel_eff: 1.8, crew: 5..10, hardpoints: 4 },
      titan:     { cargo: 2000, fuel_eff: 2.0, crew: 10..20, hardpoints: 8 }
    }.freeze

    RACES = %w[vex solari krog myrmidon].freeze
    TIERS = (1..5).to_a.freeze

    # Racial bonuses as defined in Section 10
    RACIAL_BONUSES = {
      vex:      { cargo: 1.2,  sensors: 1.0,  hull: 1.0,  cost: 1.0 },  # +20% cargo
      solari:   { cargo: 1.0,  sensors: 1.2,  hull: 1.0,  cost: 1.0 },  # +20% sensors
      krog:     { cargo: 1.0,  sensors: 1.0,  hull: 1.2,  cost: 1.0 },  # +20% hull
      myrmidon: { cargo: 1.0,  sensors: 1.0,  hull: 1.0,  cost: 0.8 }   # -20% cost
    }.freeze

    class << self
      # Generate a ship with deterministic attributes
      # @param race [String] One of: vex, solari, krog, myrmidon
      # @param hull_size [Symbol] One of: scout, frigate, transport, cruiser, titan
      # @param tier [Integer] 1-5 (quality tier, affects scaling)
      # @return [Hash] Ship attributes
      def call(race:, hull_size:, tier:)
        raise ArgumentError, "Invalid race: #{race}" unless RACES.include?(race.to_s)
        raise ArgumentError, "Invalid hull size: #{hull_size}" unless HULL_SIZES.key?(hull_size.to_sym)
        raise ArgumentError, "Tier must be 1-5" unless TIERS.include?(tier)

        base = HULL_SIZES[hull_size.to_sym]
        seed = Digest::SHA256.hexdigest("#{race}|#{hull_size}|#{tier}")

        # Extract variance factors from seed (consistent per race/hull/tier combo)
        cargo_variance = extract_variance(seed, 0, 21) - 10      # -10 to +10%
        fuel_variance = extract_variance(seed, 2, 21) - 10       # -10 to +10%
        maneuver_variance = extract_variance(seed, 4, 21) - 10   # -10 to +10%
        hull_variance = extract_variance(seed, 6, 21) - 10       # -10 to +10%
        maint_variance = extract_variance(seed, 8, 21) - 10      # -10 to +10%
        sensor_variance = extract_variance(seed, 10, 21) - 10    # -10 to +10%

        # Tier multiplier using power law (~1.8x per tier)
        tier_multiplier = 1.8 ** (tier - 1)

        # Base attributes with variance and tier scaling
        cargo = (base[:cargo] * (1 + cargo_variance / 100.0) * tier_multiplier).round
        fuel_efficiency = (base[:fuel_eff] * (1 + fuel_variance / 100.0)).round(2)
        maneuverability = calculate_maneuverability(hull_size, maneuver_variance)
        hull_points = (calculate_hull_points(hull_size, hull_variance) * tier_multiplier).round
        maintenance_rate = (calculate_maintenance(hull_size, maint_variance) * tier_multiplier).round
        sensor_range = (calculate_sensors(hull_size, sensor_variance) * tier_multiplier).round

        # Apply racial bonuses
        racial_bonus = RACIAL_BONUSES[race.to_sym]
        cargo = (cargo * racial_bonus[:cargo]).round
        sensor_range = (sensor_range * racial_bonus[:sensors]).round
        hull_points = (hull_points * racial_bonus[:hull]).round

        # Calculate cost with tier scaling
        base_cost = calculate_base_cost(hull_size)
        cost = (base_cost * tier_multiplier * racial_bonus[:cost]).round

        # Generate ship name based on tier
        ship_name = generate_ship_name(race, hull_size, tier)

        {
          race: race.to_s,
          hull_size: hull_size.to_sym,
          tier: tier,
          name: ship_name,
          cargo_capacity: cargo,
          fuel_efficiency: fuel_efficiency,
          maneuverability: maneuverability,
          hardpoints: base[:hardpoints],
          crew_min: base[:crew].min,
          crew_max: base[:crew].max,
          maintenance_rate: maintenance_rate,
          hull_points: hull_points,
          sensor_range: sensor_range,
          cost: cost,
          seed: seed
        }
      end

      # Generate all 100 ship types (4 races x 5 hull sizes x 5 tiers)
      # @return [Array<Hash>] Array of 100 ship definitions
      def generate_all_types
        ships = []
        RACES.each do |race|
          HULL_SIZES.keys.each do |hull_size|
            TIERS.each do |tier|
              ships << call(race: race, hull_size: hull_size, tier: tier)
            end
          end
        end
        ships
      end

      # Legacy method for compatibility
      def generate(race, hull_size, variant_idx, location_seed)
        # Map variant_idx (0-9) to tier (1-5) for backwards compatibility
        tier = (variant_idx / 2) + 1
        tier = tier.clamp(1, 5)
        call(race: race, hull_size: hull_size, tier: tier)
      end

      # Generate all ship variants for diversity testing (legacy)
      def generate_all_variants
        generate_all_types
      end

      # Verify racial bonuses are correctly applied
      def verify_racial_bonuses
        results = {}

        RACES.each do |race|
          race_ships = HULL_SIZES.keys.flat_map do |hull_size|
            TIERS.map { |t| call(race: race, hull_size: hull_size, tier: t) }
          end

          avg_cargo = race_ships.sum { |s| s[:cargo_capacity] } / race_ships.size.to_f
          avg_sensors = race_ships.sum { |s| s[:sensor_range] } / race_ships.size.to_f
          avg_hull = race_ships.sum { |s| s[:hull_points] } / race_ships.size.to_f
          avg_cost = race_ships.sum { |s| s[:cost] } / race_ships.size.to_f

          results[race] = {
            cargo: avg_cargo,
            sensors: avg_sensors,
            hull: avg_hull,
            cost: avg_cost
          }
        end

        results
      end

      private

      def extract_variance(seed_hex, byte_offset, range)
        ProceduralGeneration.extract_from_seed(seed_hex, byte_offset, 2, range)
      end

      def calculate_maneuverability(hull_size, variance)
        base = case hull_size.to_sym
               when :scout then 80
               when :frigate then 65
               when :transport then 40
               when :cruiser then 25
               when :titan then 10
               end
        (base + variance).clamp(1, 100)
      end

      def calculate_hull_points(hull_size, variance)
        base = case hull_size.to_sym
               when :scout then 100
               when :frigate then 250
               when :transport then 500
               when :cruiser then 1000
               when :titan then 2500
               end
        (base * (1 + variance / 100.0)).round
      end

      def calculate_maintenance(hull_size, variance)
        base = case hull_size.to_sym
               when :scout then 50
               when :frigate then 150
               when :transport then 300
               when :cruiser then 600
               when :titan then 1500
               end
        (base * (1 + variance / 100.0)).round
      end

      def calculate_sensors(hull_size, variance)
        base = case hull_size.to_sym
               when :scout then 10
               when :frigate then 8
               when :transport then 5
               when :cruiser then 12
               when :titan then 15
               end
        (base * (1 + variance / 100.0)).round
      end

      def calculate_base_cost(hull_size)
        case hull_size.to_sym
        when :scout then 10_000
        when :frigate then 50_000
        when :transport then 200_000
        when :cruiser then 1_000_000
        when :titan then 5_000_000
        end
      end

      def generate_ship_name(race, hull_size, tier)
        prefixes = {
          vex: %w[Profit Greed Fortune Credit Margin],
          solari: %w[Logic Reason Theory Axiom Proof],
          krog: %w[Hammer Fist Rage Fury Storm],
          myrmidon: %w[Swarm Hive Unity Cluster Colony]
        }

        suffixes = {
          scout: %w[Scout Seeker Finder Eye Wing],
          frigate: %w[Hunter Guard Shield Blade Edge],
          transport: %w[Hauler Carrier Mover Lifter Loader],
          cruiser: %w[Destroyer Warrior Champion Dominator Victor],
          titan: %w[Colossus Behemoth Leviathan Juggernaut Sovereign]
        }

        tier_suffix = "Mk#{['I', 'II', 'III', 'IV', 'V'][tier - 1]}"

        prefix = prefixes[race.to_sym][(tier - 1) % prefixes[race.to_sym].length]
        suffix = suffixes[hull_size.to_sym][(tier - 1) % suffixes[hull_size.to_sym].length]

        "#{prefix} #{suffix} #{tier_suffix}"
      end
    end
  end
end
