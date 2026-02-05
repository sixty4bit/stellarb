# frozen_string_literal: true

require 'digest'
require_relative 'seed_helpers'

module ProceduralGeneration
  class MineralGenerator
    include SeedHelpers

    # 50 real minerals from periodic table elements
    REAL_MINERALS = %w[
      iron copper gold silver platinum titanium aluminum nickel zinc lead
      tin tungsten cobalt chromium manganese vanadium molybdenum uranium thorium plutonium
      lithium beryllium magnesium calcium sodium potassium silicon carbon sulfur phosphorus
      mercury arsenic antimony bismuth cadmium indium gallium germanium selenium tellurium
      rubidium strontium zirconium niobium palladium rhodium ruthenium osmium iridium rhenium
    ].freeze

    # 10 made-up end-game minerals (rare)
    EXOTIC_MINERALS = %w[
      stellarium voidstone chronite darkmatter quantium
      etherealite singularite cosmic_crystal zero_point_ore omnium
    ].freeze

    DEPTHS = %w[surface shallow deep core].freeze

    # Generate minerals for a planet
    # @param planet_seed [String] The planet's seed
    # @param planet_type [String] The planet type (affects mineral distribution)
    # @return [Array<Hash>] Array of mineral deposits
    def self.call(planet_seed:, planet_type:)
      new(planet_seed: planet_seed, planet_type: planet_type).generate
    end

    def initialize(planet_seed:, planet_type:)
      @planet_seed = planet_seed
      @planet_type = planet_type
      @minerals_seed = generate_minerals_seed
    end

    def generate
      # Number of mineral deposits (1-10)
      deposit_count = extract_from_seed(minerals_seed, 0, 1, 10) + 1

      # Generate each deposit
      (0...deposit_count).map do |deposit_index|
        generate_deposit(deposit_index)
      end
    end

    private

    attr_reader :planet_seed, :planet_type, :minerals_seed

    def generate_minerals_seed
      Digest::SHA256.hexdigest("#{planet_seed}|minerals")
    end

    def generate_deposit(deposit_index)
      deposit_seed = Digest::SHA256.hexdigest("#{minerals_seed}|deposit|#{deposit_index}")

      {
        mineral: select_mineral(deposit_seed),
        quantity: generate_quantity(deposit_seed),
        purity: generate_purity(deposit_seed),
        depth: select_depth(deposit_seed)
      }
    end

    def select_mineral(deposit_seed)
      # ~2% chance for exotic minerals
      is_exotic = extract_from_seed(deposit_seed, 0, 2, 100) < 2

      if is_exotic
        exotic_idx = extract_from_seed(deposit_seed, 2, 1, EXOTIC_MINERALS.length)
        EXOTIC_MINERALS[exotic_idx]
      else
        real_idx = extract_from_seed(deposit_seed, 2, 2, REAL_MINERALS.length)
        REAL_MINERALS[real_idx]
      end
    end

    def generate_quantity(deposit_seed)
      # Quantity: 1,000 to 100,000 tons
      base_quantity = extract_from_seed(deposit_seed, 4, 3, 99_000) + 1_000

      # Adjust based on planet type
      quantity_multiplier = case planet_type
                           when 'gas_giant' then 0.1  # Harder to mine
                           when 'rocky', 'barren' then 1.5
                           when 'volcanic' then 2.0  # Rich in minerals
                           else 1.0
                           end

      (base_quantity * quantity_multiplier).to_i
    end

    def generate_purity(deposit_seed)
      # Purity: 0.1 to 1.0
      purity_int = extract_from_seed(deposit_seed, 7, 1, 10) + 1
      purity_int / 10.0
    end

    def select_depth(deposit_seed)
      depth_idx = extract_from_seed(deposit_seed, 8, 1, DEPTHS.length)
      DEPTHS[depth_idx]
    end
  end
end