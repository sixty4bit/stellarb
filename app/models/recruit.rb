# frozen_string_literal: true

class Recruit < ApplicationRecord
  # Constants
  RACES = %w[vex solari krog myrmidon].freeze
  NPC_CLASSES = %w[governor navigator engineer marine].freeze
  RARITY_TIERS = %w[common uncommon rare legendary].freeze

  # Quirk pools
  POSITIVE_QUIRKS = %w[meticulous efficient loyal frugal lucky].freeze
  NEUTRAL_QUIRKS = %w[superstitious nocturnal chatty loner gambler].freeze
  NEGATIVE_QUIRKS = %w[lazy greedy volatile reckless paranoid saboteur].freeze

  # Employer names for procedural history generation
  EMPLOYER_NAMES = [
    "Stellaris Corp", "Frontier Mining Co", "Void Runners LLC", "Titan Haulers",
    "DeepCore Mining", "Freeport Station", "Nebula Transport", "Stellar Freight",
    "Orbital Industries", "Cosmos Logistics", "Vex Trading Corp", "Solari Research",
    "Krog Heavy Industries", "Myrmidon Collective", "Colonial Authority"
  ].freeze

  # Outcome types for employment history
  CLEAN_OUTCOMES = [
    "Contract completed", "Promoted to Lead", "Company dissolved (economic)",
    "Relocated", "Position eliminated", "Voluntary departure", "Contract renewal declined"
  ].freeze

  INCIDENT_OUTCOMES = [
    "Creative differences", "Mutual separation", "Performance concerns",
    "Restructuring", "Policy disagreement", "Medical leave", "Personal reasons"
  ].freeze

  CATASTROPHE_OUTCOMES = [
    "Reactor incident (T4)", "Cargo loss (T3)", "Navigation error (T4)",
    "Security breach", "Theft investigation", "Sabotage suspected", "Criminal charges (dismissed)"
  ].freeze

  # Validations
  validates :level_tier, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :race, presence: true, inclusion: { in: RACES }
  validates :npc_class, presence: true, inclusion: { in: NPC_CLASSES }
  validates :skill, presence: true, numericality: { in: 1..100 }
  validates :chaos_factor, presence: true, numericality: { in: 0..100 }
  validates :available_at, presence: true
  validates :expires_at, presence: true

  # Attribute accessor for deterministic seed (not persisted)
  attr_accessor :seed

  # Scopes
  scope :available_for, ->(user) do
    where(level_tier: user.level_tier)
      .where("available_at <= ? AND expires_at > ?", Time.current, Time.current)
  end

  scope :available_for_tier, ->(tier) do
    where(level_tier: tier)
      .where("available_at <= ? AND expires_at > ?", Time.current, Time.current)
  end

  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Class method to generate a new recruit with all attributes populated
  # Can optionally specify npc_class to generate a specific class
  def self.generate!(level_tier:, npc_class: nil)
    recruit = new(level_tier: level_tier)
    recruit.npc_class = npc_class if npc_class.present?
    recruit.seed = SecureRandom.hex(16)
    recruit.populate_attributes!
    recruit.save!
    recruit
  end

  # Populate all procedurally generated attributes
  def populate_attributes!
    populate_core_attributes!
    generate_name!
    generate_quirks!
    generate_employment_history!
    set_availability_window!
  end

  # Determine rarity based on skill and chaos factor
  def rarity_tier
    if skill >= 90
      "legendary"
    elsif skill >= 75
      "rare"
    elsif skill >= 50
      "uncommon"
    else
      "common"
    end
  end

  # Calculate wage based on skill and rarity
  def base_wage
    wage = skill * 10 # Base wage

    # Exponential scaling for high skill
    wage *= 1.5 if skill > 80
    wage *= 2.0 if skill > 90

    # Chaos factor discount (risky hires are cheaper)
    wage *= (1.0 - chaos_factor / 200.0)

    wage.round
  end

  # Generate name from race-specific pool
  def generate_name!
    self.name = pick_name_for_race
  end

  # Generate quirks based on chaos_factor
  def generate_quirks!
    self.base_stats ||= {}
    quirks = []

    quirk_count = determine_quirk_count
    quirk_count.times do
      quirk = pick_quirk
      quirks << quirk unless quirks.include?(quirk)
    end

    self.base_stats["quirks"] = quirks
  end

  # Generate employment history
  def generate_employment_history!
    self.employment_history ||= []

    entry_count = deterministic_rand(2..5)
    entries = []

    entry_count.times do |i|
      entries << generate_employment_entry(i)
    end

    self.employment_history = entries
  end

  private

  def populate_core_attributes!
    self.race ||= RACES[deterministic_rand(0...RACES.length)]
    self.npc_class ||= NPC_CLASSES[deterministic_rand(0...NPC_CLASSES.length)]
    self.skill ||= generate_skill_with_rarity
    self.chaos_factor ||= deterministic_rand(0..100)
  end

  def set_availability_window!
    self.available_at = Time.current
    # Expires in 30-90 minutes
    minutes = deterministic_rand(30..90)
    self.expires_at = Time.current + minutes.minutes
  end

  # Generate skill based on rarity distribution
  # Common: 70%, Uncommon: 20%, Rare: 8%, Legendary: 2%
  def generate_skill_with_rarity
    roll = deterministic_rand(0..99)

    if roll < 2 # 2% legendary
      deterministic_rand(90..100)
    elsif roll < 10 # 8% rare
      deterministic_rand(75..89)
    elsif roll < 30 # 20% uncommon
      deterministic_rand(50..74)
    else # 70% common
      deterministic_rand(1..49)
    end
  end

  def determine_quirk_count
    case chaos_factor
    when 0..20 then deterministic_rand(0..1)
    when 21..50 then deterministic_rand(1..2)
    when 51..80 then deterministic_rand(1..2)
    else deterministic_rand(2..3)
    end
  end

  def pick_quirk
    # Weight by chaos factor
    # Low chaos: 70% positive, 25% neutral, 5% negative
    # High chaos: 5% positive, 25% neutral, 70% negative
    roll = deterministic_rand(0..99)

    if chaos_factor <= 20
      if roll < 70
        POSITIVE_QUIRKS[deterministic_rand(0...POSITIVE_QUIRKS.length)]
      elsif roll < 95
        NEUTRAL_QUIRKS[deterministic_rand(0...NEUTRAL_QUIRKS.length)]
      else
        NEGATIVE_QUIRKS[deterministic_rand(0...NEGATIVE_QUIRKS.length)]
      end
    elsif chaos_factor >= 81
      if roll < 5
        POSITIVE_QUIRKS[deterministic_rand(0...POSITIVE_QUIRKS.length)]
      elsif roll < 30
        NEUTRAL_QUIRKS[deterministic_rand(0...NEUTRAL_QUIRKS.length)]
      else
        NEGATIVE_QUIRKS[deterministic_rand(0...NEGATIVE_QUIRKS.length)]
      end
    else
      # Mid chaos: balanced
      if roll < 33
        POSITIVE_QUIRKS[deterministic_rand(0...POSITIVE_QUIRKS.length)]
      elsif roll < 66
        NEUTRAL_QUIRKS[deterministic_rand(0...NEUTRAL_QUIRKS.length)]
      else
        NEGATIVE_QUIRKS[deterministic_rand(0...NEGATIVE_QUIRKS.length)]
      end
    end
  end

  def pick_name_for_race
    # Names by race from ROADMAP
    names = case race
    when "vex"
      [ "Grimbly Skunt", "Fleezo Margin", "Krix Bottomline", "Zek Profitsore",
        "Targo Dealmaker", "Slink Percentile", "Vax Moneybags", "Quirrel Markup" ]
    when "solari"
      [ "7-Alpha-Null", "Research Unit Zed", "Calculus Prime", "Logic-7",
        "Hypothesis Delta", "Unit Analysis-3", "Theorem-19", "Vector Sigma" ]
    when "krog"
      [ "Smashgut Ironface", "Bork the Unpleasant", "Captain Dents", "Grudge Hammerton",
        "Krang Breakstuff", "Thud McPunchface", "Grim Hardknock", "Bash Rockfist" ]
    when "myrmidon"
      [ "Cluster 447", "The Swarm That Hums", "Unit Formerly Known As 12", "Colony-Mind 8",
        "Drone Alpha-7", "Collective 23", "Hiveling 99", "Node Delta-Prime" ]
    else
      [ "Unknown Worker #{deterministic_rand(100..999)}" ]
    end

    names[deterministic_rand(0...names.length)]
  end

  def generate_employment_entry(index)
    employer = EMPLOYER_NAMES[deterministic_rand(0...EMPLOYER_NAMES.length)]
    duration = "#{deterministic_rand(1..24)} months"
    outcome = pick_outcome

    {
      "employer" => employer,
      "duration" => duration,
      "outcome" => outcome
    }
  end

  def pick_outcome
    # Outcome distribution based on chaos factor
    # 0-20:   90% clean, 10% incident, 0% catastrophe
    # 21-50:  70% clean, 25% incident, 5% catastrophe
    # 51-80:  40% clean, 45% incident, 15% catastrophe
    # 81-100: 10% clean, 50% incident, 40% catastrophe
    roll = deterministic_rand(0..99)

    clean_threshold, incident_threshold = case chaos_factor
    when 0..20
      [ 90, 100 ]
    when 21..50
      [ 70, 95 ]
    when 51..80
      [ 40, 85 ]
    else
      [ 10, 60 ]
    end

    if roll < clean_threshold
      "clean_exit"
    elsif roll < incident_threshold
      INCIDENT_OUTCOMES[deterministic_rand(0...INCIDENT_OUTCOMES.length)]
    else
      CATASTROPHE_OUTCOMES[deterministic_rand(0...CATASTROPHE_OUTCOMES.length)]
    end
  end

  # Deterministic random number generation using the seed
  # Falls back to regular rand if no seed is set
  def deterministic_rand(range)
    if @seed.present?
      # Use seed to create deterministic random
      @prng ||= Random.new(Digest::SHA256.hexdigest(@seed).to_i(16) % (2**31))
      @prng.rand(range)
    else
      rand(range)
    end
  end
end
