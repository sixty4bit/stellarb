class WarpGate < ApplicationRecord
  # Constants
  STATUSES = %w[active offline].freeze
  WARP_FUEL_COST = 5.0  # Flat fuel cost for warp travel

  # Associations
  belongs_to :system_a, class_name: 'System'
  belongs_to :system_b, class_name: 'System'

  # Validations
  validates :short_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :systems_must_be_different
  validate :no_duplicate_gate

  # Callbacks
  before_validation :generate_short_id, on: :create
  before_validation :set_default_status, on: :create

  # Scopes
  scope :active, -> { where(status: 'active') }

  # Find gate between two systems (order-independent)
  def self.between(system_a, system_b)
    where(system_a: system_a, system_b: system_b)
      .or(where(system_a: system_b, system_b: system_a))
      .first
  end

  # Check if two systems are connected by an active gate
  def self.connected?(system_a, system_b)
    active.between(system_a, system_b).present?
  end

  def active?
    status == 'active'
  end

  def connects?(system)
    system_a_id == system.id || system_b_id == system.id
  end

  def other_system(from_system)
    if system_a_id == from_system.id
      system_b
    elsif system_b_id == from_system.id
      system_a
    end
  end

  private

  def generate_short_id
    return if short_id.present?

    base = "wg-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while WarpGate.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def set_default_status
    self.status ||= 'active'
  end

  def systems_must_be_different
    if system_a_id.present? && system_a_id == system_b_id
      errors.add(:base, "Cannot create warp gate to the same system")
    end
  end

  def no_duplicate_gate
    return unless system_a_id.present? && system_b_id.present?

    existing = WarpGate.where.not(id: id).between(system_a, system_b)
    if existing.present?
      errors.add(:base, "Warp gate already exists between these systems")
    end
  end
end
