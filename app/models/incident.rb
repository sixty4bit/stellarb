# frozen_string_literal: true

class Incident < ApplicationRecord
  # Severity tier mappings
  SEVERITY_TIERS = {
    1 => { name: "minor_glitch", loss: 5, auto_resolve: true, remote_fixable: true },
    2 => { name: "component_failure", loss: 15, auto_resolve: false, remote_fixable: true },
    3 => { name: "system_failure", loss: 35, auto_resolve: false, remote_fixable: false },
    4 => { name: "critical_damage", loss: 50, auto_resolve: false, remote_fixable: false },
    5 => { name: "catastrophe", loss: 80, auto_resolve: false, remote_fixable: false }
  }.freeze

  NEARBY_NPC_FAILURE_CHANCE = 0.40

  NEARBY_NPC_FAILURE_MESSAGES = [
    "They tried to fix it. They made it worse.",
    "Turns out they caused the first problem too.",
    "Good intentions, bad execution. The damage has escalated.",
    "They stared at the problem, poked it, and now it's angrier."
  ].freeze

  # Associations
  belongs_to :asset, polymorphic: true
  belongs_to :hired_recruit, optional: true

  # Validations
  validates :severity, presence: true, inclusion: { in: 1..5 }
  validates :description, presence: true

  # Callbacks
  before_create :generate_uuid
  after_create :record_in_employment_history
  after_create :disable_asset_if_pip_infestation

  # Scopes
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :unresolved, -> { where(resolved_at: nil) }
  scope :pip_infestations, -> { where(is_pip_infestation: true) }
  scope :for_npc, ->(npc) { where(hired_recruit: npc) }

  # Severity tier helpers

  def severity_tier
    SEVERITY_TIERS[severity]
  end

  def severity_tier_name
    severity_tier[:name]
  end

  def functionality_loss_percent
    # Pip infestations cause total loss (asset disabled)
    return 100 if is_pip_infestation?
    severity_tier[:loss]
  end

  def auto_resolvable?
    !is_pip_infestation? && severity_tier[:auto_resolve]
  end

  def remote_fixable?
    !is_pip_infestation? && severity_tier[:remote_fixable]
  end

  def requires_physical_presence?
    is_pip_infestation? || !severity_tier[:remote_fixable]
  end

  def nearly_total_loss?
    severity == 5 || is_pip_infestation?
  end

  # Resolution

  def resolved?
    resolved_at.present?
  end

  def resolve!
    update!(resolved_at: Time.current)
  end

  def resolve_with_assistant!(assistant)
    raise "Assistant is on cooldown" if assistant.on_cooldown?

    transaction do
      resolve!
      assistant.update!(assistant_cooldown_until: Time.current + HiredRecruit::ASSISTANT_COOLDOWN)
      send_resolution_message!("Your assistant resolved the incident: #{description}")
    end
  end

  def resolve_with_nearby_npc!(npc, random: Random.new)
    roll = random.rand

    if roll >= NEARBY_NPC_FAILURE_CHANCE
      # Success
      transaction do
        resolve!
        send_resolution_message!("A nearby crew member resolved the incident: #{description}")
      end
    else
      # Failure — create escalated incident
      failure_message = NEARBY_NPC_FAILURE_MESSAGES.sample(random: random)
      new_severity = [severity + 1, 5].min

      transaction do
        Incident.create!(
          asset: asset,
          severity: new_severity,
          description: failure_message
        )
        send_resolution_message!(failure_message, title: "Resolution Failed", urgent: true)
      end
    end
  end

  def can_use_nearby_npc?(npc)
    npc.hirings.where(assignable: asset).exists?
  end

  def purge!
    return unless is_pip_infestation?

    transaction do
      update!(resolved_at: Time.current)
      re_enable_asset!
    end
  end

  private

  def send_resolution_message!(body, title: "Incident Update", urgent: false)
    asset.user.messages.create!(
      title: title,
      body: body,
      from: "Incident Management",
      category: "incident",
      urgent: urgent
    )
  end

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def record_in_employment_history
    return unless hired_recruit.present?

    hired_recruit.add_incident(severity, description)
  end

  def disable_asset_if_pip_infestation
    return unless is_pip_infestation?

    asset.update!(disabled_at: Time.current)
  end

  def re_enable_asset!
    asset.update!(disabled_at: nil)
  end
end
