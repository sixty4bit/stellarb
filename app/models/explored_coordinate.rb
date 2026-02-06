# Tracks coordinates that a user has explored
# These can be at any x,y,z position - not necessarily where a system exists
class ExploredCoordinate < ApplicationRecord
  belongs_to :user

  # Validations
  validates :x, :y, :z, presence: true
  validates :x, uniqueness: { scope: [:user_id, :y, :z], message: "coordinates already explored" }

  # Scopes
  scope :with_systems, -> { where(has_system: true) }
  scope :empty, -> { where(has_system: false) }
  scope :in_direction, ->(axis, positive) {
    case axis
    when :x then positive ? where("x > ?", 0) : where("x < ?", 0)
    when :y then positive ? where("y > ?", 0) : where("y < ?", 0)
    when :z then positive ? where("z > ?", 0) : where("z < ?", 0)
    end
  }

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
end
