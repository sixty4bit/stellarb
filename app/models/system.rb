class System < ApplicationRecord
  # Associations
  belongs_to :discovered_by, class_name: 'User', optional: true
  has_many :buildings, dependent: :destroy
  has_many :ships, foreign_key: 'current_system_id'

  # Validations
  validates :x, presence: true, numericality: { in: 0..999_999 }
  validates :y, presence: true, numericality: { in: 0..999_999 }
  validates :z, presence: true, numericality: { in: 0..999_999 }
  validates :short_id, presence: true, uniqueness: true
  validates :name, presence: true

  # Ensure unique coordinates
  validates_uniqueness_of :x, scope: [:y, :z]

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :set_name, on: :create
  before_validation :set_properties, on: :create

  # Check if this is The Cradle
  def is_cradle?
    x == 0 && y == 0 && z == 0
  end

  private

  def generate_short_id
    return if short_id.present?

    base = "sy-#{name[0, 3].downcase}" if name.present?
    base ||= "sy-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while System.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def set_name
    return if name.present?

    if is_cradle?
      self.name = "The Cradle"
    else
      # Generate a unique system name based on coordinates
      # This is a placeholder - could be enhanced with a name generator
      self.name = "System-#{x}-#{y}-#{z}"
    end
  end

  def set_properties
    return if properties.present?

    # Generate system properties using the procedural generator
    seed = Digest::SHA256.hexdigest("#{x}|#{y}|#{z}")

    if is_cradle?
      # The Cradle has fixed tutorial properties
      self.properties = {
        star_type: 'yellow_dwarf',
        planet_count: 5,
        hazard_level: 0,
        security_level: 'high',
        is_tutorial_zone: true
      }
    else
      # Use procedural generation for other systems
      self.properties = ProceduralGeneration::SystemGenerator.call(
        seed: 'stellarb',
        x: x,
        y: y,
        z: z
      )
    end
  end
end
