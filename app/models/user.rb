class User < ApplicationRecord
  include TripleId

  # Associations
  has_many :ships, dependent: :destroy
  has_many :buildings, dependent: :destroy
  has_many :discovered_systems, class_name: 'System', foreign_key: 'discovered_by_id'
  has_many :hirings, dependent: :destroy
  has_many :hired_recruits, through: :hirings
  has_many :system_visits, dependent: :destroy
  has_many :visited_systems, through: :system_visits, source: :system
  has_many :routes, dependent: :destroy
  has_many :flight_records, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :level_tier, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :credits, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :generate_short_id, on: :create

  # ===========================================
  # Travel Log (Visitor History)
  # ===========================================

  # Returns user's system visits ordered by most recent visit
  # @param limit [Integer] Maximum number of entries to return (nil for all)
  # @return [ActiveRecord::Relation<SystemVisit>]
  def travel_log(limit: nil)
    visits = system_visits.by_last_visit
    limit ? visits.limit(limit) : visits
  end

  # ===========================================
  # Flight Recorder (Movement History)
  # ===========================================

  # Returns user's flight history (all movements) ordered by most recent
  # @param limit [Integer] Maximum number of entries to return (nil for all)
  # @return [ActiveRecord::Relation<FlightRecord>]
  def flight_history(limit: nil)
    records = flight_records.recent_first
    limit ? records.limit(limit) : records
  end

  # Calculate total distance traveled by this user
  # @return [Decimal] Total distance in game units
  def total_distance_traveled
    flight_records.sum(:distance)
  end

  private

  def generate_short_id
    return if short_id.present?

    base = "u-#{name[0, 3].downcase}" if name.present?
    base ||= "u-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while User.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end
end
