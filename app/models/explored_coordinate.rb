# Tracks coordinates a user has explored in the galaxy
# Used for discovery mechanics and exploration progress
class ExploredCoordinate < ApplicationRecord
  belongs_to :user

  validates :x, :y, :z, presence: true
  validates :x, uniqueness: { scope: [:user_id, :y, :z] }

  # Scopes
  scope :with_systems, -> { where(has_system: true) }
  scope :empty, -> { where(has_system: false) }

  # Check if a coordinate has been explored by a user
  # @param user [User] The user to check
  # @param x [Integer] X coordinate
  # @param y [Integer] Y coordinate
  # @param z [Integer] Z coordinate
  # @return [Boolean]
  def self.explored?(user:, x:, y:, z:)
    exists?(user: user, x: x, y: y, z: z)
  end

  # Mark a coordinate as explored
  # @param user [User] The user who explored
  # @param x [Integer] X coordinate
  # @param y [Integer] Y coordinate
  # @param z [Integer] Z coordinate
  # @param has_system [Boolean] Whether a system exists at this coordinate
  # @return [ExploredCoordinate]
  def self.mark_explored!(user:, x:, y:, z:, has_system: false)
    find_or_create_by!(user: user, x: x, y: y, z: z) do |coord|
      coord.has_system = has_system
    end
  end

  # Calculate distance from origin (0,0,0)
  # @return [Float] Euclidean distance from origin
  def distance_from_origin
    Math.sqrt(x**2 + y**2 + z**2)
  end

  # Calculate orbital distance (rounded to nearest integer for bucketing)
  # @return [Integer] Distance bucket for orbital rings
  def orbital_distance
    distance_from_origin.round
  end
end
