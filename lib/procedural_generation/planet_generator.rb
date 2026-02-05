# frozen_string_literal: true

require 'digest'
require_relative 'seed_helpers'
require_relative 'mineral_generator'
require_relative 'plant_generator'

module ProceduralGeneration
  class PlanetGenerator
    include SeedHelpers

    PLANET_TYPES = %w[
      rocky gas_giant ice volcanic oceanic desert jungle barren
    ].freeze

    PLANET_SIZES = %w[
      small medium large massive
    ].freeze

    # Name prefixes and suffixes for procedural generation
    NAME_PREFIXES = %w[
      Kepler Sigma Tau Alpha Beta Gamma Delta Epsilon Zeta Eta
      Theta Iota Kappa Lambda Mu Nu Xi Omicron Pi Rho
      Sol Luna Terra Nova Proxima Centauri Andromeda Perseus Orion
    ].freeze

    NAME_SUFFIXES = %w[
      Prime Minor Major Alpha Beta Gamma Delta One Two Three
      Four Five Six Seven Eight Nine Ten Eleven Twelve
      b c d e f g h i j k
    ].freeze

    # Generate a planet for a system
    # @param system_seed [String] The system's seed
    # @param planet_index [Integer] Index of planet in system (0-based)
    # @return [Hash] Planet data
    def self.call(system_seed:, planet_index:)
      new(system_seed: system_seed, planet_index: planet_index).generate
    end

    def initialize(system_seed:, planet_index:)
      @system_seed = system_seed
      @planet_index = planet_index
      @planet_seed = generate_planet_seed
    end

    def generate
      type = planet_type

      {
        name: generate_name,
        type: type,
        size: planet_size,
        minerals: MineralGenerator.call(planet_seed: planet_seed, planet_type: type),
        plants: PlantGenerator.call(planet_seed: planet_seed, planet_type: type)
      }
    end

    private

    attr_reader :system_seed, :planet_index, :planet_seed

    def generate_planet_seed
      Digest::SHA256.hexdigest("#{system_seed}|planet|#{planet_index}")
    end

    def generate_name
      # Use planet seed to deterministically pick name components
      prefix_idx = extract_from_seed(planet_seed, 0, 2, NAME_PREFIXES.length)
      suffix_idx = extract_from_seed(planet_seed, 2, 2, NAME_SUFFIXES.length)

      prefix = NAME_PREFIXES[prefix_idx]
      suffix = NAME_SUFFIXES[suffix_idx]

      # Some variation in name format based on another seed value
      name_format = extract_from_seed(planet_seed, 4, 1, 3)

      case name_format
      when 0
        "#{prefix}-#{planet_index + 1}#{suffix[0]}" # e.g., "Kepler-7b"
      when 1
        "#{prefix} #{suffix}" # e.g., "Zeta Prime"
      else
        "#{prefix}-#{suffix}" # e.g., "Sol-Minor"
      end
    end

    def planet_type
      type_idx = extract_from_seed(planet_seed, 5, 1, PLANET_TYPES.length)
      PLANET_TYPES[type_idx]
    end

    def planet_size
      size_idx = extract_from_seed(planet_seed, 6, 1, PLANET_SIZES.length)
      PLANET_SIZES[size_idx]
    end
  end
end