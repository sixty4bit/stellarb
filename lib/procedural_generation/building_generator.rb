# frozen_string_literal: true

require 'digest'

module ProceduralGeneration
  class BuildingGenerator
    # Building types as defined in Section 5.2.1
    BUILDING_TYPES = {
      # Resource Extraction
      mineral_mine: {
        function: :extraction,
        inputs: { energy: 10 },
        outputs: { minerals: 20 },
        staff: { engineer: 1, marine: 1 },
        planet_requirement: :rocky,
        tiers: 1..5
      },
      gas_harvester: {
        function: :extraction,
        inputs: { energy: 15 },
        outputs: { gas: 30 },
        staff: { engineer: 2 },
        planet_requirement: :gas_giant,
        tiers: 1..5
      },
      water_extractor: {
        function: :extraction,
        inputs: { energy: 5 },
        outputs: { water: 50 },
        staff: { engineer: 1 },
        planet_requirement: :ice_or_ocean,
        tiers: 1..3
      },

      # Processing & Refinement
      ore_refinery: {
        function: :refining,
        inputs: { raw_ore: 100, energy: 20 },
        outputs: { refined_metal: 30 },
        staff: { engineer: 2, governor: 1 },
        efficiency_range: 0.5..1.5
      },
      chemical_plant: {
        function: :refining,
        inputs: { gas: 50, water: 20, energy: 30 },
        outputs: { chemicals: 40 },
        staff: { engineer: 3 },
        hazard_modifier: 1.5
      },

      # Infrastructure
      warehouse: {
        function: :logistics,
        storage: 10000,
        decay_rate: 0.01,
        staff: { governor: 1 },
        defense_bonus: 0
      },
      habitat: {
        function: :civic,
        population_support: 1000,
        tax_generation: true,
        staff: { governor: 2, marine: 1 },
        morale_factors: [:food_supply, :entertainment, :security]
      },
      defense_platform: {
        function: :defense,
        firepower: 100,
        range: 10,
        staff: { marine: 3 },
        activation: :battle_mode_only
      }
    }.freeze

    FUNCTIONS = %i[extraction refining logistics civic defense].freeze
    RACES = %w[vex solari krog myrmidon].freeze
    TIERS = (1..5).to_a

    # Racial building focuses as defined in Section 9
    RACIAL_FOCUSES = {
      vex: {
        preferred_types: %i[logistics civic],
        efficiency_modifier: { income: 1.2, corruption: 1.3 },
        special_buildings: %w[casino trade_hub black_market]
      },
      solari: {
        preferred_types: %i[extraction refining],
        efficiency_modifier: { tech: 1.2, energy_cost: 1.3 },
        special_buildings: %w[research_lab sensor_array shield_generator]
      },
      krog: {
        preferred_types: %i[refining defense],
        efficiency_modifier: { durability: 1.3, pollution: 1.2 },
        special_buildings: %w[shipyard bunker armory]
      },
      myrmidon: {
        preferred_types: %i[civic extraction],
        efficiency_modifier: { population: 1.2, cost: 0.8 },
        special_buildings: %w[hydroponics clone_vats hive_housing]
      }
    }.freeze

    class << self
      # Generate a building with deterministic attributes
      # @param race [String] One of: vex, solari, krog, myrmidon
      # @param function [Symbol] One of: extraction, refining, logistics, civic, defense
      # @param tier [Integer] 1-5
      # @param location_seed [String] Location-based seed for regional variation
      # @return [Hash] Building attributes
      def generate(race, function, tier, location_seed)
        raise ArgumentError, "Invalid race: #{race}" unless RACES.include?(race.to_s)
        raise ArgumentError, "Invalid function: #{function}" unless FUNCTIONS.include?(function.to_sym)
        raise ArgumentError, "Tier must be 1-5" unless TIERS.include?(tier)

        seed = Digest::SHA256.hexdigest("#{race}|#{function}|#{tier}|#{location_seed}")

        # Select building type based on function
        building_type = select_building_type(function, race, seed)
        base = BUILDING_TYPES[building_type]

        # Generate tier-scaled attributes
        attributes = generate_attributes(base, tier, seed)

        # Apply racial modifiers
        apply_racial_modifiers!(attributes, race, function)

        # Calculate costs based on tier
        cost = calculate_cost(tier, function)

        # Generate building name
        name = generate_building_name(race, building_type, tier)

        {
          race: race,
          function: function,
          building_type: building_type,
          tier: tier,
          name: name,
          attributes: attributes,
          cost: cost,
          seed: seed
        }
      end

      # Generate all building variants for diversity testing
      def generate_all_variants
        buildings = []
        RACES.each do |race|
          FUNCTIONS.each do |function|
            TIERS.each do |tier|
              buildings << generate(race, function, tier, "standard_location_seed")
            end
          end
        end
        buildings
      end

      # Verify tier scaling follows power law (Section 10.2)
      def verify_tier_scaling
        results = {}

        FUNCTIONS.each do |function|
          tier_data = TIERS.map do |tier|
            building = generate("vex", function, tier, "test_seed")

            # Calculate effective output based on building type
            output = if building[:attributes][:outputs]
                       # For production buildings, sum all outputs
                       building[:attributes][:outputs].values.sum
                     elsif building[:attributes][:storage]
                       # For storage buildings, use storage capacity
                       building[:attributes][:storage]
                     elsif building[:attributes][:firepower]
                       # For defense buildings, use firepower
                       building[:attributes][:firepower]
                     elsif building[:attributes][:population_support]
                       # For civic buildings, use population support
                       building[:attributes][:population_support]
                     else
                       0
                     end

            {
              tier: tier,
              cost: building[:cost],
              output: output
            }
          end

          # Check if cost increases by ~1.8x and output by appropriate scaling
          cost_ratios = []
          output_ratios = []

          tier_data.each_cons(2) do |t1, t2|
            cost_ratios << t2[:cost].to_f / t1[:cost]
            output_ratios << t2[:output].to_f / t1[:output] if t1[:output] > 0 && t2[:output] > 0
          end

          results[function] = {
            avg_cost_ratio: cost_ratios.sum / cost_ratios.size,
            avg_output_ratio: output_ratios.empty? ? 0 : output_ratios.sum / output_ratios.size
          }
        end

        results
      end

      private

      def select_building_type(function, race, seed)
        candidates = BUILDING_TYPES.select { |_, data| data[:function] == function }.keys

        # Prefer racial special buildings
        racial_focus = RACIAL_FOCUSES[race.to_sym]
        if racial_focus[:preferred_types].include?(function)
          # Higher chance of getting specialized building
          special_chance = ProceduralGeneration.extract_from_seed(seed, 0, 1, 100)
          if special_chance > 70 && racial_focus[:special_buildings].any?
            # Return a special building type (would be expanded in full implementation)
            return candidates.first
          end
        end

        # Select from available candidates
        idx = ProceduralGeneration.extract_from_seed(seed, 1, 1, candidates.length)
        candidates[idx]
      end

      def generate_attributes(base, tier, seed)
        attributes = {}

        # Scale inputs/outputs by tier
        if base[:inputs]
          attributes[:inputs] = base[:inputs].transform_values do |v|
            (v * (tier ** 0.8)).round # Inputs scale slower than outputs
          end
        end

        if base[:outputs]
          attributes[:outputs] = base[:outputs].transform_values do |v|
            (v * (tier ** 1.2)).round # Outputs scale faster (power law)
          end
        end

        # Scale other attributes
        attributes[:storage] = (base[:storage] * (tier ** 1.1)).round if base[:storage]
        attributes[:firepower] = (base[:firepower] * (tier ** 1.3)).round if base[:firepower]
        attributes[:population_support] = (base[:population_support] * tier).round if base[:population_support]

        # Copy fixed attributes
        attributes[:staff] = base[:staff]
        attributes[:planet_requirement] = base[:planet_requirement] if base[:planet_requirement]
        attributes[:decay_rate] = base[:decay_rate] if base[:decay_rate]

        # Add variance
        variance = ProceduralGeneration.extract_from_seed(seed, 10, 2, 21) - 10 # -10 to +10%
        attributes[:efficiency_modifier] = 1.0 + (variance / 100.0)

        attributes
      end

      def apply_racial_modifiers!(attributes, race, function)
        racial_focus = RACIAL_FOCUSES[race.to_sym]
        modifiers = racial_focus[:efficiency_modifier]

        # Apply racial efficiency bonuses
        if racial_focus[:preferred_types].include?(function)
          attributes[:efficiency_modifier] = (attributes[:efficiency_modifier] || 1.0) * 1.1
        end

        # Apply specific racial traits
        case race.to_sym
        when :vex
          attributes[:corruption_rate] = 0.1 * modifiers[:corruption]
          attributes[:income_bonus] = modifiers[:income]
        when :solari
          if attributes[:inputs]
            attributes[:inputs][:energy] = (attributes[:inputs][:energy] * modifiers[:energy_cost]).round if attributes[:inputs][:energy]
          end
        when :krog
          attributes[:durability_bonus] = modifiers[:durability]
          attributes[:pollution_output] = modifiers[:pollution]
        when :myrmidon
          if attributes[:population_support]
            attributes[:population_support] = (attributes[:population_support] * modifiers[:population]).round
          end
        end
      end

      def calculate_cost(tier, function)
        base_costs = {
          extraction: 10_000,
          refining: 25_000,
          logistics: 15_000,
          civic: 20_000,
          defense: 30_000
        }

        base = base_costs[function]
        # Cost increases by ~1.8x per tier
        (base * (1.8 ** (tier - 1))).round
      end

      def generate_building_name(race, building_type, tier)
        type_names = {
          mineral_mine: "Mine",
          gas_harvester: "Harvester",
          water_extractor: "Extractor",
          ore_refinery: "Refinery",
          chemical_plant: "Chemical Plant",
          warehouse: "Warehouse",
          habitat: "Habitat",
          defense_platform: "Defense Platform"
        }

        racial_prefixes = {
          vex: %w[Profitable Golden Premium Luxury Elite],
          solari: %w[Efficient Optimal Advanced Quantum Photonic],
          krog: %w[Heavy Armored Fortified Brutal Massive],
          myrmidon: %w[Collective Swarm Hive Unity Colony]
        }

        tier_suffix = "Mark #{['I', 'II', 'III', 'IV', 'V'][tier - 1]}"

        prefix = racial_prefixes[race.to_sym][tier - 1]
        type_name = type_names[building_type] || building_type.to_s.split('_').map(&:capitalize).join(' ')

        "#{prefix} #{type_name} #{tier_suffix}"
      end
    end
  end
end