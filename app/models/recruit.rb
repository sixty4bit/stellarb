class Recruit < ApplicationRecord
  # Constants
  RACES = %w[vex solari krog myrmidon].freeze
  NPC_CLASSES = %w[governor navigator engineer marine].freeze
  RARITY_TIERS = %w[common uncommon rare legendary].freeze

  # Validations
  validates :level_tier, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :race, presence: true, inclusion: { in: RACES }
  validates :npc_class, presence: true, inclusion: { in: NPC_CLASSES }
  validates :skill, presence: true, numericality: { in: 1..100 }
  validates :chaos_factor, presence: true, numericality: { in: 0..100 }
  validates :available_at, presence: true
  validates :expires_at, presence: true

  # Scopes
  scope :available_for, ->(user) do
    where(level_tier: user.level_tier)
      .where("available_at <= ? AND expires_at > ?", Time.current, Time.current)
  end

  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Determine rarity based on skill and chaos factor
  def rarity_tier
    if skill >= 90
      'legendary'
    elsif skill >= 75
      'rare'
    elsif skill >= 50
      'uncommon'
    else
      'common'
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
end
