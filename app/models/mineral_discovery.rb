# frozen_string_literal: true

# Tracks which futuristic minerals a player has discovered.
#
# Futuristic minerals are hidden from players until they discover them
# by mining in the correct system type. Once discovered, the mineral
# becomes visible in all systems where it naturally occurs.
#
# Reference: Source doc Section 1.2
class MineralDiscovery < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :discovered_in_system, class_name: "System", optional: true

  # Validations
  validates :mineral_name, presence: true
  validates :mineral_name, uniqueness: { scope: :user_id }
  validate :mineral_must_be_futuristic

  # Callbacks
  before_validation :set_discovered_at, on: :create

  # Valid futuristic mineral names
  FUTURISTIC_MINERAL_NAMES = Minerals::FUTURISTIC.map { |m| m[:name] }.freeze

  # Check if a mineral name is a valid futuristic mineral
  # @param name [String] Mineral name to check
  # @return [Boolean] True if futuristic
  def self.futuristic_mineral?(name)
    FUTURISTIC_MINERAL_NAMES.include?(name)
  end

  private

  def mineral_must_be_futuristic
    return if mineral_name.blank?

    unless self.class.futuristic_mineral?(mineral_name)
      errors.add(:mineral_name, "must be a futuristic mineral")
    end
  end

  def set_discovered_at
    self.discovered_at ||= Time.current
  end
end
