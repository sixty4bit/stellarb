# Tracks coordinates that a user has explored in the galaxy
class ExploredCoordinate < ApplicationRecord
  belongs_to :user

  validates :x, :y, :z, presence: true
  validates :x, uniqueness: { scope: [:user_id, :y, :z] }

  scope :at, ->(x, y, z) { where(x: x, y: y, z: z) }
end
