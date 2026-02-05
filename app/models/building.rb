class Building < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :system
  has_many :hirings, as: :assignable, dependent: :destroy
  has_many :staff, through: :hirings, source: :hired_recruit

  # Constants
  RACES = %w[vex solari krog myrmidon].freeze
  FUNCTIONS = %w[extraction refining logistics civic defense].freeze
  STATUSES = %w[active inactive destroyed under_construction].freeze

  # Validations
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :race, presence: true, inclusion: { in: RACES }
  validates :function, presence: true, inclusion: { in: FUNCTIONS }
  validates :tier, presence: true, numericality: { in: 1..5 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :generate_building_attributes, on: :create

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_function, ->(function) { where(function: function) }

  private

  def generate_short_id
    return if short_id.present?

    abbrev = case function
    when 'extraction' then 'ext'
    when 'refining' then 'ref'
    when 'logistics' then 'log'
    when 'civic' then 'civ'
    when 'defense' then 'def'
    else 'bld'
    end

    base = "bl-#{abbrev}#{tier}"
    candidate = base
    counter = 2

    while Building.exists?(short_id: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def generate_building_attributes
    return if building_attributes.present?

    # This is a placeholder - would use the procedural generation engine
    base_stats = {
      staff_slots: { min: 2, max: 5 },
      maintenance_rate: 20 * tier,
      hardpoints: tier,
      storage_capacity: 1000 * tier,
      output_rate: 10 * (tier ** 1.5),
      power_consumption: 5 * tier,
      durability: 500 * tier
    }

    # Apply function-specific modifications
    case function
    when 'extraction'
      base_stats[:output_rate] *= 2
    when 'defense'
      base_stats[:hardpoints] *= 2
      base_stats[:durability] *= 1.5
    when 'logistics'
      base_stats[:storage_capacity] *= 3
    end

    # Apply racial bonuses
    case race
    when 'vex'
      base_stats[:output_rate] *= 1.1 if function == 'civic'
    when 'solari'
      base_stats[:power_consumption] *= 1.2
    when 'krog'
      base_stats[:durability] *= 1.2
    when 'myrmidon'
      base_stats[:maintenance_rate] *= 0.8
    end

    self.building_attributes = base_stats
  end
end
