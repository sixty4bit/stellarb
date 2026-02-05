# frozen_string_literal: true

# Triple-ID System Concern
#
# Provides a consistent identification pattern across all game entities:
# - Full Name: Human-readable name for display
# - Short ID: Compact reference code (e.g., "sh-yam", "sy-cra")
# - UUID v7: Time-sortable globally unique identifier
#
# Include this concern in any model that needs the triple-ID system.
# The model must have `name`, `short_id`, and `uuid` columns.
#
module TripleId
  extend ActiveSupport::Concern

  included do
    before_validation :generate_uuid, on: :create

    validates :uuid, presence: true, uniqueness: true, on: :update
    validates :uuid, format: {
      with: /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i,
      message: "must be a valid UUID v7"
    }, allow_blank: true
  end

  # Returns all three identifiers as a hash
  # @return [Hash] { name:, short_id:, uuid: }
  def triple_id
    {
      name: name,
      short_id: short_id,
      uuid: uuid
    }
  end

  private

  # Generate a UUID v7 (time-sortable UUID)
  # UUID v7 format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
  # - First 48 bits: Unix timestamp in milliseconds
  # - Next 4 bits: Version (7)
  # - Next 12 bits: Random
  # - Next 2 bits: Variant (10)
  # - Last 62 bits: Random
  def generate_uuid
    return if uuid.present?

    self.uuid = self.class.generate_uuid7
  end

  class_methods do
    # Generate a UUID v7
    # @return [String] UUID v7 in standard format (xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx)
    def generate_uuid7
      # Get current timestamp in milliseconds
      timestamp_ms = (Time.current.to_f * 1000).to_i

      # Extract 48 bits of timestamp
      timestamp_hex = format('%012x', timestamp_ms & 0xffffffffffff)

      # Generate random bytes
      random_bytes = SecureRandom.random_bytes(10)
      random_hex = random_bytes.unpack1('H*')

      # Build UUID v7
      # Positions: time_high (8) - time_mid (4) - ver+rand (4) - var+rand (4) - rand (12)
      time_high = timestamp_hex[0, 8]
      time_mid = timestamp_hex[8, 4]

      # Version 7 + 12 bits of randomness
      ver_rand = '7' + random_hex[0, 3]

      # Variant (10xx) + 12 bits of randomness
      variant_byte = (random_hex[3, 2].to_i(16) & 0x3f) | 0x80
      var_rand = format('%02x', variant_byte) + random_hex[5, 2]

      # Last 48 bits of randomness
      rand_end = random_hex[7, 12]

      "#{time_high}-#{time_mid}-#{ver_rand}-#{var_rand}-#{rand_end}"
    end
  end
end
