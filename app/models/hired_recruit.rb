class HiredRecruit < ApplicationRecord
  # Associations
  belongs_to :original_recruit, class_name: 'Recruit', optional: true
  has_many :hirings, dependent: :destroy
  has_many :users, through: :hirings

  # Constants (same as Recruit)
  RACES = Recruit::RACES
  NPC_CLASSES = Recruit::NPC_CLASSES

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

  # Delegate some methods to maintain consistency
  delegate :rarity_tier, to: :original_recruit, allow_nil: true

  # Generate a display name (NPCs don't have stored names - derived from class and id)
  def name
    "#{npc_class.humanize} ##{id}"
  end

  # Calculate wage with modifiers
  def calculate_wage(modifier = 1.0)
    base = skill * 10
    base *= 1.5 if skill > 80
    base *= 2.0 if skill > 90
    base *= modifier
    base.round
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
