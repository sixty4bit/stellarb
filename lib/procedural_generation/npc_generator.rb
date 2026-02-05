# frozen_string_literal: true

require 'digest'
require 'yaml'

module ProceduralGeneration
  class NpcGenerator
    NPC_CLASSES = %w[governor navigator engineer marine].freeze
    RACES = %w[vex solari krog myrmidon].freeze
    RARITY_TIERS = {
      common: { weight: 70, skill_range: 20..60 },
      uncommon: { weight: 20, skill_range: 40..75 },
      rare: { weight: 8, skill_range: 60..85 },
      legendary: { weight: 2, skill_range: 75..100 }
    }.freeze

    # Quirks organized by impact type
    QUIRKS = {
      positive: %w[meticulous efficient loyal frugal lucky focused dedicated inspiring],
      neutral: %w[superstitious nocturnal chatty loner methodical cautious traditional spontaneous],
      negative: %w[lazy greedy volatile reckless paranoid saboteur argumentative forgetful]
    }.freeze

    # Racial skill bonuses from Section 10.3
    RACIAL_BONUSES = {
      vex: {
        skills: { barter: 10, luck: 5 },
        required_trait: "greedy",
        salary_modifier: 1.2
      },
      solari: {
        skills: { science: 10, navigation: 5 },
        required_trait: "cold",
        morale_modifier: 0.8
      },
      krog: {
        skills: { combat: 10, engineering: 5 },
        required_trait: "volatile",
        strike_chance_modifier: 1.5
      },
      myrmidon: {
        skills: { agriculture: 10, industry: 5 },
        required_trait: "hive_mind",
        minimum_group_size: 3
      }
    }.freeze

    # Employment outcome templates
    EMPLOYMENT_OUTCOMES = {
      clean: [
        "Contract completed",
        "Promoted to Lead",
        "Company dissolved (economic)",
        "Honorable discharge",
        "Project completed successfully",
        "Transferred to sister company"
      ],
      incident: [
        "Creative differences",
        "Mutual separation",
        "Restructuring",
        "Budget cuts",
        "Equipment malfunction",
        "Minor workplace incident"
      ],
      catastrophe: [
        "Reactor incident (T4)",
        "Navigation error - lost cargo",
        "Security breach - assets compromised",
        "Catastrophic system failure",
        "Multiple safety violations",
        "Gross insubordination"
      ]
    }.freeze

    class << self
      # Generate NPCs for a recruiter pool rotation
      # @param level_tier [Integer] Player level tier (1-10)
      # @param active_players [Integer] Number of active players at this tier
      # @param timestamp [Time] Rotation timestamp for seed
      # @return [Array<Hash>] Array of NPC data
      def generate_pool(level_tier, active_players, timestamp)
        pool_size = calculate_pool_size(active_players)
        seed_base = "#{level_tier}|#{timestamp.to_i}"

        npcs = []
        pool_size.times do |slot_idx|
          npcs << generate_npc(level_tier, timestamp, slot_idx)
        end

        npcs
      end

      # Generate a single NPC
      # @param level_tier [Integer] Player level tier
      # @param timestamp [Time] Rotation timestamp
      # @param slot_idx [Integer] Slot index in pool
      # @return [Hash] NPC attributes
      def generate_npc(level_tier, timestamp, slot_idx)
        seed = Digest::SHA256.hexdigest("#{level_tier}|#{timestamp.to_i}|#{slot_idx}")

        # Determine basic attributes
        race_idx = ProceduralGeneration.extract_from_seed(seed, 0, 1, RACES.length)
        race = RACES[race_idx]

        class_idx = ProceduralGeneration.extract_from_seed(seed, 1, 1, NPC_CLASSES.length)
        npc_class = NPC_CLASSES[class_idx]

        rarity = determine_rarity(seed)
        skill = generate_skill(rarity, seed)

        # Hidden chaos factor (affects failure rates)
        chaos_factor = ProceduralGeneration.extract_from_seed(seed, 4, 1, 101) # 0-100

        # Generate quirks based on chaos factor
        quirks = generate_quirks(chaos_factor, seed)

        # Add required racial trait
        racial_trait = RACIAL_BONUSES[race.to_sym][:required_trait]
        quirks << racial_trait unless quirks.include?(racial_trait)

        # Generate employment history
        employment_history = generate_employment_history(chaos_factor, seed)

        # Get name from pool or generate
        name = generate_name(race, seed)

        {
          race: race,
          npc_class: npc_class,
          name: name,
          skill: skill,
          rarity: rarity,
          chaos_factor: chaos_factor, # Hidden from players
          quirks: quirks.uniq,
          employment_history: employment_history,
          level_tier_requirement: level_tier,
          base_wage: calculate_base_wage(skill, rarity)
        }
      end

      # Generate employment history based on chaos factor
      def generate_employment_history(chaos_factor, seed)
        # 2-5 prior jobs
        job_count = ProceduralGeneration.extract_from_seed(seed, 10, 1, 4) + 2
        history = []

        job_count.times do |i|
          job_seed = "#{seed}|job_#{i}"
          job_hash = Digest::SHA256.hexdigest(job_seed)

          # Duration in months (chaos = shorter tenures)
          if chaos_factor > 80
            duration = ProceduralGeneration.extract_from_seed(job_hash, 0, 1, 6) + 1 # 1-6 months
          elsif chaos_factor > 50
            duration = ProceduralGeneration.extract_from_seed(job_hash, 0, 1, 12) + 6 # 6-18 months
          else
            duration = ProceduralGeneration.extract_from_seed(job_hash, 0, 1, 24) + 12 # 12-36 months
          end

          # Outcome based on chaos factor
          outcome = generate_employment_outcome(chaos_factor, job_hash)

          # Employer name
          employer = generate_employer_name(job_hash)

          # Check for employment gap
          if i > 0 && chaos_factor > 70 && ProceduralGeneration.extract_from_seed(job_hash, 5, 1, 100) > 80
            gap_months = ProceduralGeneration.extract_from_seed(job_hash, 6, 1, 8) + 1
            history << {
              employer: "Unlisted (gap)",
              duration_months: gap_months,
              outcome: nil
            }
          end

          history << {
            employer: employer,
            duration_months: duration,
            outcome: outcome
          }
        end

        history
      end

      private

      def calculate_pool_size(active_players)
        # Based on Section 5.1.5: (active_players * 0.3) per class, minimum 10
        per_class = [(active_players * 0.3).round, 10].max
        per_class * NPC_CLASSES.length
      end

      def determine_rarity(seed)
        roll = ProceduralGeneration.extract_from_seed(seed, 2, 1, 100)

        cumulative = 0
        RARITY_TIERS.each do |tier, data|
          cumulative += data[:weight]
          return tier if roll < cumulative
        end

        :common # Fallback
      end

      def generate_skill(rarity, seed)
        range = RARITY_TIERS[rarity][:skill_range]
        skill_variance = ProceduralGeneration.extract_from_seed(seed, 3, 1, range.size)
        range.min + skill_variance
      end

      def generate_quirks(chaos_factor, seed)
        # Quirk count based on chaos factor
        quirk_count = case chaos_factor
                      when 0..20 then [0, 1].sample
                      when 21..50 then [1, 2].sample
                      when 51..80 then [1, 2].sample
                      when 81..100 then [2, 3].sample
                      end

        quirks = []
        quirk_count.times do |i|
          quirk_seed = ProceduralGeneration.extract_from_seed(seed, 20 + i * 2, 2, 100)

          # Weight by chaos factor
          if chaos_factor < 30
            pool_weights = { positive: 70, neutral: 25, negative: 5 }
          elsif chaos_factor < 70
            pool_weights = { positive: 30, neutral: 40, negative: 30 }
          else
            pool_weights = { positive: 5, neutral: 25, negative: 70 }
          end

          # Select pool
          pool_roll = quirk_seed % 100
          pool = if pool_roll < pool_weights[:positive]
                   :positive
                 elsif pool_roll < pool_weights[:positive] + pool_weights[:neutral]
                   :neutral
                 else
                   :negative
                 end

          # Select quirk from pool
          quirk_idx = ProceduralGeneration.extract_from_seed(seed, 22 + i * 2, 1, QUIRKS[pool].length)
          quirks << QUIRKS[pool][quirk_idx]
        end

        quirks
      end

      def generate_employment_outcome(chaos_factor, job_hash)
        # Outcome probabilities based on chaos factor (Section 5.1.6)
        roll = ProceduralGeneration.extract_from_seed(job_hash, 1, 1, 100)

        if chaos_factor <= 20
          # 90% clean, 10% incident, 0% catastrophe
          if roll < 90
            outcome_type = :clean
          else
            outcome_type = :incident
          end
        elsif chaos_factor <= 50
          # 70% clean, 25% incident, 5% catastrophe
          if roll < 70
            outcome_type = :clean
          elsif roll < 95
            outcome_type = :incident
          else
            outcome_type = :catastrophe
          end
        elsif chaos_factor <= 80
          # 40% clean, 45% incident, 15% catastrophe
          if roll < 40
            outcome_type = :clean
          elsif roll < 85
            outcome_type = :incident
          else
            outcome_type = :catastrophe
          end
        else
          # 10% clean, 50% incident, 40% catastrophe
          if roll < 10
            outcome_type = :clean
          elsif roll < 60
            outcome_type = :incident
          else
            outcome_type = :catastrophe
          end
        end

        outcomes = EMPLOYMENT_OUTCOMES[outcome_type]
        outcome_idx = ProceduralGeneration.extract_from_seed(job_hash, 2, 1, outcomes.length)
        outcomes[outcome_idx]
      end

      def generate_employer_name(job_hash)
        prefixes = ["Stellar", "Quantum", "Nexus", "Cosmic", "Orbital", "Frontier", "Deep", "Void", "Galactic", "Nova"]
        middles = ["Mining", "Transport", "Security", "Research", "Trading", "Manufacturing", "Energy", "Defense", "Logistics", "Systems"]
        suffixes = ["Corp", "LLC", "Industries", "Enterprises", "Co", "Group", "Syndicate", "Consortium", "Holdings", "Solutions"]

        prefix_idx = ProceduralGeneration.extract_from_seed(job_hash, 3, 1, prefixes.length)
        middle_idx = ProceduralGeneration.extract_from_seed(job_hash, 4, 1, middles.length)
        suffix_idx = ProceduralGeneration.extract_from_seed(job_hash, 5, 1, suffixes.length)

        "#{prefixes[prefix_idx]} #{middles[middle_idx]} #{suffixes[suffix_idx]}"
      end

      def generate_name(race, seed)
        # Load names from YAML if available, otherwise use procedural generation
        names_file = Rails.root.join('db', 'seeds', 'npc_names.yml')

        if File.exist?(names_file)
          names_data = YAML.load_file(names_file)
          race_names = names_data[race] || []

          if race_names.any?
            name_idx = ProceduralGeneration.extract_from_seed(seed, 30, 2, race_names.length)
            return race_names[name_idx]
          end
        end

        # Fallback procedural generation
        first_names = {
          vex: %w[Grimbly Fleezo Krix Zapper Margin Profit Swindol Lucre],
          solari: %w[Alpha Beta Gamma Delta Epsilon Zeta Theta Sigma],
          krog: %w[Smash Bork Grunt Thud Crash Boom Slam Krunk],
          myrmidon: %w[Cluster Unit Drone Node Swarm Hive Colony Matrix]
        }

        last_names = {
          vex: %w[Skunt Margin Bottomline Goldgrab Cashflow Profit Greed Hoard],
          solari: %w[Null Prime Zero One Binary Hex Octal Decimal],
          krog: %w[Ironface Steelfist Rockjaw Smashgut Doomhammer Waraxe Bloodfist Skullcrusher],
          myrmidon: %w[447 Alpha-9 Beta-3 Gamma-7 Delta-2 Epsilon-5 Zeta-1 Theta-8]
        }

        first_idx = ProceduralGeneration.extract_from_seed(seed, 31, 1, first_names[race.to_sym].length)
        last_idx = ProceduralGeneration.extract_from_seed(seed, 32, 1, last_names[race.to_sym].length)

        "#{first_names[race.to_sym][first_idx]} #{last_names[race.to_sym][last_idx]}"
      end

      def calculate_base_wage(skill, rarity)
        # Exponential wage scaling based on skill
        base = 100
        skill_multiplier = (1.03 ** skill) # 3% increase per skill point

        # Rarity bonus
        rarity_multiplier = case rarity
                            when :common then 1.0
                            when :uncommon then 1.5
                            when :rare then 2.5
                            when :legendary then 5.0
                            end

        (base * skill_multiplier * rarity_multiplier).round
      end
    end
  end
end