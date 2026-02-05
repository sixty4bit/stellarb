class Ship < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :current_system, class_name: 'System', optional: true
  has_many :hirings, as: :assignable, dependent: :destroy
  has_many :crew, through: :hirings, source: :hired_recruit

  # Constants
  RACES = %w[vex solari krog myrmidon].freeze
  HULL_SIZES = %w[scout frigate transport cruiser titan].freeze
  STATUSES = %w[docked in_transit combat destroyed].freeze

  # Validations
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :race, presence: true, inclusion: { in: RACES }
  validates :hull_size, presence: true, inclusion: { in: HULL_SIZES }
  validates :variant_idx, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fuel, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Either current_system or location coordinates must be present
  validate :must_have_location

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :generate_ship_attributes, on: :create

  # Scopes
  scope :active, -> { where.not(status: 'destroyed') }
  scope :docked, -> { where(status: 'docked') }
  scope :in_transit, -> { where(status: 'in_transit') }

  private

  def generate_short_id
    return if short_id.present?

    base = "sh-#{name[0, 3].downcase}" if name.present?
    base ||= "sh-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while Ship.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def generate_ship_attributes
    return if ship_attributes.present?

    # This is a placeholder - would use the procedural generation engine
    base_stats = {
      cargo_capacity: 100,
      fuel_efficiency: 1.0,
      maneuverability: 50,
      hardpoints: 2,
      crew_slots: { min: 2, max: 4 },
      maintenance_rate: 10,
      hull_points: 100,
      sensor_range: 10
    }

    # Apply racial bonuses
    case race
    when 'vex'
      base_stats[:cargo_capacity] *= 1.2
    when 'solari'
      base_stats[:sensor_range] *= 1.2
    when 'krog'
      base_stats[:hull_points] *= 1.2
    when 'myrmidon'
      base_stats[:maintenance_rate] *= 0.8
    end

    self.ship_attributes = base_stats
  end

  def must_have_location
    if current_system_id.blank? && (location_x.blank? || location_y.blank? || location_z.blank?)
      errors.add(:base, "Ship must have either a current system or location coordinates")
    end
  end
end
