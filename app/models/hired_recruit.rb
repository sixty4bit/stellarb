class HiredRecruit < ApplicationRecord
  # Associations
  belongs_to :original_recruit, class_name: 'Recruit', optional: true
  has_many :hirings, dependent: :destroy
  has_many :users, through: :hirings

  # Constants (same as Recruit)
  RACES = Recruit::RACES
  NPC_CLASSES = Recruit::NPC_CLASSES

  # Wage calculation constants
  # Based on ROADMAP Section 4.4.3: "The Wage Spiral"
  # Higher skill NPCs demand exponentially higher wages
  # Target: skill_90_wage > skill_80_wage * 1.5
  # Target: skill_95_wage > skill_75_wage * 3 (legendary premium)
  BASE_WAGE = 50                # Base wage for skill 1
  GROWTH_FACTOR = 1.06          # Exponential growth factor per skill point
                                # 1.06^10 = 1.79x (passes skill 80->90 test)
                                # 1.06^20 = 3.21x (passes skill 75->95 test)
  CHAOS_DISCOUNT_FACTOR = 0.003 # Max 30% discount at chaos 100

  # Racial wage modifiers (per ROADMAP Section 10.3)
  # Vex: Trait "Greedy" (Higher Salary)
  RACIAL_WAGE_MODIFIERS = {
    'vex' => 1.15,       # +15% wages (Greedy trait)
    'solari' => 1.0,     # Neutral
    'krog' => 0.95,      # -5% (less negotiation savvy)
    'myrmidon' => 0.85   # -15% (hive workers, cheaper)
  }.freeze

  # Quirk system (per ROADMAP Section 5.1.5)
  # Quirks are personality traits that affect NPC performance
  # Higher Chaos Factor = more disruptive quirks
  POSITIVE_QUIRKS = %w[meticulous efficient loyal frugal lucky vigilant dedicated precise resourceful calm].freeze
  NEUTRAL_QUIRKS = %w[superstitious nocturnal chatty loner gambler eccentric perfectionist stubborn curious secretive].freeze
  NEGATIVE_QUIRKS = %w[lazy greedy volatile reckless paranoid saboteur alcoholic forgetful clumsy dishonest].freeze

  # Performance modifiers for each quirk
  # Positive quirks improve performance, negative reduce it
  # Values are multiplicative modifiers (1.0 = neutral)
  QUIRK_EFFECTS = {
    # Positive quirks (+5% to +15%)
    'meticulous' => 1.10,
    'efficient' => 1.15,
    'loyal' => 1.05,
    'frugal' => 1.05,
    'lucky' => 1.08,
    'vigilant' => 1.10,
    'dedicated' => 1.12,
    'precise' => 1.10,
    'resourceful' => 1.08,
    'calm' => 1.05,
    # Neutral quirks (±5%)
    'superstitious' => 0.98,
    'nocturnal' => 1.0,
    'chatty' => 0.97,
    'loner' => 1.02,
    'gambler' => 1.0,  # High variance handled elsewhere
    'eccentric' => 0.98,
    'perfectionist' => 1.03,
    'stubborn' => 0.97,
    'curious' => 1.02,
    'secretive' => 1.0,
    # Negative quirks (-5% to -20%)
    'lazy' => 0.85,
    'greedy' => 0.90,
    'volatile' => 0.88,
    'reckless' => 0.85,
    'paranoid' => 0.92,
    'saboteur' => 0.80,
    'alcoholic' => 0.82,
    'forgetful' => 0.90,
    'clumsy' => 0.88,
    'dishonest' => 0.85
  }.freeze

  # Employment History System (per ROADMAP Section 5.1.6)
  # Every NPC comes with procedurally generated work history
  # Outcomes are weighted by chaos factor

  EMPLOYER_NAMES = [
    "Stellaris Corp", "Frontier Mining Co", "Void Runners LLC",
    "DeepCore Mining", "Titan Haulers", "Freeport Station",
    "Orbital Dynamics", "Nova Shipping", "Asteroid Ventures",
    "Colonial Authority", "Galactic Trade Union", "Nebula Freight",
    "StarCore Industries", "Helix Manufacturing", "Quantum Logistics",
    "Aether Refining", "Terminus Station", "Vanguard Security",
    "Crescent Hauling", "Apex Contractors"
  ].freeze

  CLEAN_EXIT_OUTCOMES = [
    "Contract completed",
    "Promoted to Lead",
    "Transferred internally",
    "Company dissolved (economic)",
    "Relocated with family",
    "Retired honorably"
  ].freeze

  INCIDENT_OUTCOMES = [
    "Creative differences",
    "Mutual separation",
    "Downsized",
    "Contract not renewed",
    "Personal reasons",
    "Medical leave",
    "Investigation pending",
    "Performance review failed"
  ].freeze

  CATASTROPHE_OUTCOMES = [
    "Reactor incident",
    "Cargo loss",
    "Navigation error",
    "Sabotage suspected",
    "Criminal investigation",
    "Theft allegation",
    "Negligence discharge"
  ].freeze

  # ==========================================
  # Aging System Constants (ROADMAP Section 4.4.3)
  # ==========================================

  # Lifespan range in game-days
  # Game target is 20-30 days (stellarb-a7q.2)
  # NPCs should last longer than a game but be finite
  BASE_LIFESPAN_MIN = 30   # Minimum lifespan for lowest skill
  BASE_LIFESPAN_MAX = 100  # Maximum base lifespan
  SKILL_LIFESPAN_BONUS = 0.8  # Per skill point bonus to lifespan

  # Elderly threshold (percentage of lifespan)
  ELDERLY_THRESHOLD = 0.8  # 80% of lifespan = elderly

  # Display name - use custom_name from hiring if set, otherwise class + race
  def name
    "#{npc_class.humanize} (#{race.humanize})"
  end

  # Validations
  validates :race, presence: true, inclusion: { in: RACES }
  validates :npc_class, presence: true, inclusion: { in: NPC_CLASSES }
  validates :skill, presence: true, numericality: { in: 1..100 }
  validates :chaos_factor, presence: true, numericality: { in: 0..100 }
  validates :age_days, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :lifespan_days, numericality: { greater_than: 0 }, allow_nil: true

  # Callbacks
  before_create :generate_lifespan

  # Create from a Recruit (immutable copy)
  def self.create_from_recruit!(recruit, hiring_user)
    create!(
      original_recruit: recruit,
      race: recruit.race,
      npc_class: recruit.npc_class,
      skill: recruit.skill,
      stats: recruit.base_stats.deep_dup,
      employment_history: recruit.employment_history.deep_dup,
      chaos_factor: recruit.chaos_factor
    )
  end

  # Class method for exponential wage calculation
  # Can be used without an instance for projections/calculations
  def self.exponential_wage(skill:, chaos_factor: 0, race: nil, modifier: 1.0)
    # Exponential formula: base * growth_factor^skill
    # This ensures skill 90 wage > skill 80 wage * 1.5 (ROADMAP requirement)
    base = BASE_WAGE * (GROWTH_FACTOR ** skill)

    # Apply chaos discount (risky hires are cheaper)
    # chaos_factor 0 = no discount, 100 = max ~30% discount
    chaos_discount = 1.0 - (chaos_factor * CHAOS_DISCOUNT_FACTOR)

    # Apply racial modifier
    racial_modifier = race ? RACIAL_WAGE_MODIFIERS.fetch(race, 1.0) : 1.0

    # Calculate final wage
    wage = base * chaos_discount * racial_modifier * modifier
    wage.round
  end

  # Delegate some methods to maintain consistency
  delegate :rarity_tier, to: :original_recruit, allow_nil: true

  # Generate a display name (NPCs don't have stored names - derived from class and id)
  def name
    "#{npc_class.humanize} ##{id}"
  end

  # Calculate wage using exponential formula
  # This method uses instance attributes and delegates to the class method
  def calculate_wage(modifier = 1.0)
    self.class.exponential_wage(
      skill: skill,
      chaos_factor: chaos_factor,
      race: race,
      modifier: modifier
    )
  end

  # Add incident to employment history
  def add_incident(severity, description)
    self.employment_history ||= []
    self.employment_history << {
      date: Time.current,
      severity: severity,
      description: description
    }
    save!
  end

  # ==========================================
  # Quirk System (Chaos Factor Effects)
  # ==========================================

  # Access quirks from stats jsonb
  def quirks
    stats&.dig("quirks") || []
  end

  # Generate quirks based on chaos factor
  # Quirk count and type distribution determined by chaos level
  def generate_quirks!
    self.stats ||= {}
    self.stats["quirks"] = generate_quirks_for_chaos(chaos_factor)
    self.stats
  end

  # Calculate performance modifier from all quirks
  # Returns a multiplicative modifier (1.0 = neutral)
  def performance_modifier
    return 1.0 if quirks.empty?

    quirks.reduce(1.0) do |modifier, quirk|
      effect = QUIRK_EFFECTS.fetch(quirk, 1.0)
      modifier * effect
    end.round(3)
  end

  # ==========================================
  # Employment History System
  # ==========================================

  # Generate procedural employment history based on chaos factor
  # Creates 2-5 prior employment records
  def generate_employment_history!
    self.employment_history = generate_history_for_chaos(chaos_factor)
    self.employment_history
  end

  # Add a new employment record to history
  def add_employment_record(employer:, duration_months:, outcome:)
    self.employment_history ||= []
    self.employment_history << {
      "employer" => employer,
      "duration_months" => duration_months,
      "outcome" => outcome
    }
    save!
  end

  # Format employment history as readable resume text
  def formatted_resume
    return "No prior employment" if employment_history.nil? || employment_history.empty?

    lines = ["Prior Employment:"]
    employment_history.each do |record|
      duration = "#{record['duration_months']} month#{'s' unless record['duration_months'] == 1}"
      lines << "• #{record['employer']} — #{duration} — #{record['outcome']}"
    end
    lines.join("\n")
  end

  # ==========================================
  # Aging System (ROADMAP Section 4.4.3)
  # ==========================================

  # Calculate age as a percentage of lifespan (0.0 to 1.0+)
  # Returns 1.0 if lifespan is 0 to avoid division by zero
  def age_percentage
    return 1.0 if lifespan_days.nil? || lifespan_days <= 0
    (age_days || 0).to_f / lifespan_days
  end

  # Returns true if NPC is past 80% of their lifespan
  # Elderly NPCs may have reduced effectiveness (see decay formula)
  def elderly?
    age_percentage >= ELDERLY_THRESHOLD
  end

  # Returns true if NPC has exceeded their expected lifespan
  # These NPCs are at high risk of retirement/death
  def past_lifespan?
    return true if lifespan_days.nil? || lifespan_days <= 0
    (age_days || 0) > lifespan_days
  end

  # Calculate days remaining until expected lifespan
  # Returns 0 if already past lifespan
  def days_remaining
    return 0 if lifespan_days.nil?
    remaining = lifespan_days - (age_days || 0)
    [remaining, 0].max
  end

  private

  # Generate quirks based on chaos factor using ROADMAP rules
  def generate_quirks_for_chaos(chaos)
    count = quirk_count_for_chaos(chaos)
    return [] if count == 0

    pool = build_weighted_quirk_pool(chaos)
    selected = []

    count.times do
      break if pool.empty?
      quirk = pool.sample
      selected << quirk
      pool.delete(quirk) # No duplicates
    end

    selected
  end

  # Determine quirk count based on chaos factor (ROADMAP Section 5.1.5)
  def quirk_count_for_chaos(chaos)
    case chaos
    when 0..20   then rand(0..1)   # 0-1 quirks
    when 21..50  then rand(1..2)   # 1-2 quirks
    when 51..80  then rand(1..2)   # 1-2 quirks
    when 81..100 then rand(2..3)   # 2-3 quirks
    else 0
    end
  end

  # Build a weighted pool of quirks based on chaos factor
  # Low chaos = mostly positive, high chaos = mostly negative
  def build_weighted_quirk_pool(chaos)
    pool = []

    # Weights determine how many copies of each type go in the pool
    weights = quirk_weights_for_chaos(chaos)

    weights[:positive].times { pool.concat(POSITIVE_QUIRKS) }
    weights[:neutral].times { pool.concat(NEUTRAL_QUIRKS) }
    weights[:negative].times { pool.concat(NEGATIVE_QUIRKS) }

    pool
  end

  # Return weights for positive/neutral/negative quirks based on chaos
  # Per ROADMAP:
  # - Low chaos: 70% positive, 25% neutral, 5% negative
  # - High chaos: 5% positive, 25% neutral, 70% negative
  def quirk_weights_for_chaos(chaos)
    case chaos
    when 0..20
      { positive: 14, neutral: 5, negative: 1 }  # ~70% / ~25% / ~5%
    when 21..50
      { positive: 8, neutral: 6, negative: 6 }   # ~40% / ~30% / ~30%
    when 51..80
      { positive: 2, neutral: 5, negative: 13 }  # ~10% / ~25% / ~65%
    when 81..100
      { positive: 1, neutral: 5, negative: 14 }  # ~5% / ~25% / ~70%
    else
      { positive: 1, neutral: 1, negative: 1 }
    end
  end

  # ==========================================
  # Employment History Generation (Private)
  # ==========================================

  # Generate employment history records based on chaos factor
  def generate_history_for_chaos(chaos)
    record_count = rand(2..5)
    used_employers = []

    record_count.times.map do
      employer = select_unique_employer(used_employers, chaos)
      used_employers << employer

      duration = calculate_duration_for_chaos(chaos)
      outcome = select_outcome_for_chaos(chaos)

      {
        "employer" => employer,
        "duration_months" => duration,
        "outcome" => outcome
      }
    end
  end

  # Select a unique employer, with chance of "gap" for high chaos
  def select_unique_employer(used, chaos)
    # High chaos: 15% chance of employment gap
    if chaos > 60 && rand(100) < 15
      return "Unlisted (gap)"
    end

    available = EMPLOYER_NAMES - used
    available = EMPLOYER_NAMES if available.empty?
    available.sample
  end

  # Calculate duration based on chaos factor
  # High chaos = shorter tenures (red flag for hiring)
  def calculate_duration_for_chaos(chaos)
    case chaos
    when 0..20
      rand(8..36)   # 8-36 months (stable)
    when 21..50
      rand(4..24)   # 4-24 months (normal)
    when 51..80
      rand(2..14)   # 2-14 months (concerning)
    when 81..100
      rand(1..6)    # 1-6 months (red flag)
    else
      rand(4..18)
    end
  end

  # Select outcome based on chaos factor (ROADMAP Section 5.1.6)
  # Low chaos: 90% clean, 10% incident, 0% catastrophe
  # High chaos: 10% clean, 50% incident, 40% catastrophe
  def select_outcome_for_chaos(chaos)
    weights = outcome_weights_for_chaos(chaos)
    pool = []

    weights[:clean].times { pool.concat(CLEAN_EXIT_OUTCOMES) }
    weights[:incident].times { pool.concat(INCIDENT_OUTCOMES) }
    weights[:catastrophe].times { pool.concat(CATASTROPHE_OUTCOMES) }

    pool.sample
  end

  # Outcome probability weights by chaos level
  def outcome_weights_for_chaos(chaos)
    case chaos
    when 0..20
      { clean: 18, incident: 2, catastrophe: 0 }  # 90% / 10% / 0%
    when 21..50
      { clean: 14, incident: 5, catastrophe: 1 }  # 70% / 25% / 5%
    when 51..80
      { clean: 8, incident: 9, catastrophe: 3 }   # 40% / 45% / 15%
    when 81..100
      { clean: 2, incident: 10, catastrophe: 8 }  # 10% / 50% / 40%
    else
      { clean: 10, incident: 5, catastrophe: 1 }
    end
  end

  # ==========================================
  # Lifespan Generation
  # ==========================================

  # Generate lifespan based on skill level
  # Higher skill = longer lifespan (they're more valuable)
  # Formula: base + (skill * bonus) + random variance
  def generate_lifespan
    return if lifespan_days.present?

    # Base lifespan with skill bonus
    # Skill 1: ~30-50 days, Skill 100: ~110-130 days
    skill_bonus = (skill || 50) * SKILL_LIFESPAN_BONUS
    base = BASE_LIFESPAN_MIN + skill_bonus

    # Add some random variance (±20%)
    variance = base * 0.2
    actual = base + rand(-variance..variance)

    # Clamp to valid range
    self.lifespan_days = actual.round.clamp(BASE_LIFESPAN_MIN, 180)
  end
end
