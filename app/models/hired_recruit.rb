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

  # Display name - use custom_name from hiring if set, otherwise class + race
  def name
    "#{npc_class.humanize} (#{race.humanize})"
  end

  # Validations
  validates :race, presence: true, inclusion: { in: RACES }
  validates :npc_class, presence: true, inclusion: { in: NPC_CLASSES }
  validates :skill, presence: true, numericality: { in: 1..100 }
  validates :chaos_factor, presence: true, numericality: { in: 0..100 }

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
end
