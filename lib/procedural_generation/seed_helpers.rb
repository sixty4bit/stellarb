# frozen_string_literal: true

module ProceduralGeneration
  module SeedHelpers
    # Extract a value from a seed hex string
    # @param seed_hex [String] 64-character hex string (256 bits)
    # @param byte_offset [Integer] Starting byte position (0-31)
    # @param byte_length [Integer] Number of bytes to extract (1-4)
    # @param max_value [Integer] Maximum value to return (uses modulo)
    # @return [Integer] Value between 0 and max_value-1
    def extract_from_seed(seed_hex, byte_offset, byte_length, max_value)
      # Each hex character = 4 bits, so 2 chars = 1 byte
      slice = seed_hex[byte_offset * 2, byte_length * 2]
      slice.to_i(16) % max_value
    end
  end
end