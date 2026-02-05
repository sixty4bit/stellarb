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
  has_many :player_quests, dependent: :destroy
  has_many :quests, through: :player_quests
  has_many :messages, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :level_tier, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :credits, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Tutorial Phase Enum
  # Phase 1: cradle - Learn basics at (0,0,0)
  # Phase 2: proving_ground - Exploration in Talos Arm
  # Phase 3: emigration - The Drop to open galaxy
  # graduated - Full game access
  enum :tutorial_phase, {
    cradle: "cradle",
    proving_ground: "proving_ground",
    emigration: "emigration",
    graduated: "graduated"
  }, default: :cradle

  TUTORIAL_PHASES = %w[cradle proving_ground emigration graduated].freeze

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

  # ===========================================
  # Quest System
  # ===========================================

  # Start a quest for this user
  # @param quest [Quest] The quest to start
  # @return [PlayerQuest] The created progress record
  def start_quest(quest)
    raise ArgumentError, "Cannot start quest - not available" unless can_start_quest?(quest)

    player_quests.create!(quest: quest)
  end

  # Check if user can start a specific quest
  # @param quest [Quest] The quest to check
  # @return [Boolean]
  def can_start_quest?(quest)
    return false if player_quests.exists?(quest: quest) # Already started/completed

    # Quest 1 is always available
    return true if quest.sequence == 1

    # If this is quest 2, check if quest 1 in same galaxy is completed
    quest1 = Quest.for_galaxy(quest.galaxy).find { |q| q.sequence == 1 }
    return false unless quest1

    progress = player_quests.find_by(quest: quest1)
    progress&.completed?
  end

  # Get current active quest for this user
  # @return [PlayerQuest, nil]
  def active_quest
    player_quests.active.first
  end

  # Check if user has completed all quests in a galaxy
  # @param galaxy [String] Galaxy identifier
  # @return [Boolean]
  def completed_galaxy?(galaxy)
    galaxy_quests = Quest.for_galaxy(galaxy)
    galaxy_quests.all? { |q| player_quests.finished.exists?(quest: q) }
  end

  # ===========================================
  # Tutorial Phase System
  # ===========================================

  # Advance to the next tutorial phase
  # Does nothing if already graduated
  def advance_tutorial_phase!
    current_index = TUTORIAL_PHASES.index(tutorial_phase)
    return if current_index.nil? || current_index >= TUTORIAL_PHASES.length - 1

    next_phase = TUTORIAL_PHASES[current_index + 1]
    update!(tutorial_phase: next_phase)
  end

  # Check if user is still in tutorial
  # @return [Boolean]
  def in_tutorial?
    !graduated?
  end

  # Check if user can graduate from tutorial
  # @return [Boolean] true only when in emigration phase
  def can_graduate?
    emigration?
  end

  # Check if user has completed the Cradle phase requirements
  # Requires: at least one profitable automated route
  # @return [Boolean]
  def cradle_complete?
    routes.where(status: "active").where("total_profit > 0").exists?
  end

  # Check if user can leave the Cradle
  # Must be in cradle phase and have completed objectives
  # @return [Boolean]
  def can_leave_cradle?
    cradle? && cradle_complete?
  end

  # Check if user has a route that qualifies for supply chain tutorial
  # @return [Boolean]
  def has_qualifying_supply_chain?
    routes.any?(&:meets_supply_chain_tutorial?)
  end

  # ===========================================
  # Proving Ground (Phase 2)
  # ===========================================

  # Get available reserved systems for Phase 2 exploration
  # Only accessible to users in proving_ground phase
  # @return [Array<Hash>] List of reserved system data (empty if not in phase 2)
  def available_proving_ground_systems
    return [] unless proving_ground?

    ProceduralGeneration::ReservedSystem.all_reserved_systems
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
