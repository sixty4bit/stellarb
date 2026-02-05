# frozen_string_literal: true

# Service for calculating and applying pip damage effects.
# Implements the damage effects from ROADMAP Section 15.
#
# Effects:
# - Output reduction: Disabled assets produce nothing
# - Maintenance increase: Scales with infestation duration
# - Destruction risk: Long-standing infestations risk total loss
class PipDamageService
  # Days before destruction risk starts
  DESTRUCTION_GRACE_PERIOD = 14

  # Maximum destruction risk (per day after grace period)
  MAX_DESTRUCTION_RISK = 0.05

  # Maintenance multiplier per day of infestation
  MAINTENANCE_INCREASE_PER_DAY = 0.1

  class << self
    # Get the output modifier for an asset (0 = no output, 1 = full output)
    def output_modifier(asset)
      return 1.0 unless has_active_pip_infestation?(asset)

      # Pip-infested assets are disabled and produce nothing
      0
    end

    # Get the maintenance modifier for an asset (1 = normal, >1 = increased)
    def maintenance_modifier(asset)
      return 1.0 unless has_active_pip_infestation?(asset)

      incident = active_pip_infestation(asset)
      days_infested = ((Time.current - incident.created_at) / 1.day).to_i

      # Maintenance increases 10% per day of infestation
      1.0 + (days_infested * MAINTENANCE_INCREASE_PER_DAY)
    end

    # Get the destruction risk for an asset (0 = no risk, 1 = certain destruction)
    def destruction_risk(asset)
      return 0 unless has_active_pip_infestation?(asset)

      incident = active_pip_infestation(asset)
      days_infested = ((Time.current - incident.created_at) / 1.day).to_i

      # No risk during grace period
      return 0 if days_infested < DESTRUCTION_GRACE_PERIOD

      # After grace period, risk increases each day
      days_over_grace = days_infested - DESTRUCTION_GRACE_PERIOD
      [days_over_grace * 0.01, MAX_DESTRUCTION_RISK].min
    end

    # Get comprehensive damage summary for an asset
    def damage_summary(asset)
      incident = active_pip_infestation(asset)

      if incident
        days_infested = ((Time.current - incident.created_at) / 1.day).to_i

        {
          infested: true,
          output_modifier: output_modifier(asset),
          maintenance_modifier: maintenance_modifier(asset),
          destruction_risk: destruction_risk(asset),
          days_infested: days_infested,
          incident_id: incident.id
        }
      else
        {
          infested: false,
          output_modifier: 1.0,
          maintenance_modifier: 1.0,
          destruction_risk: 0,
          days_infested: 0,
          incident_id: nil
        }
      end
    end

    # Process potential destruction for an asset
    def process_potential_destruction(asset)
      risk = destruction_risk(asset)

      return { destroyed: false, message: nil } if risk <= 0

      if should_destroy?(risk)
        destroy_asset(asset)
      else
        { destroyed: false, message: nil }
      end
    end

    # Check if asset should be destroyed based on risk
    def should_destroy?(risk)
      rand < risk
    end

    private

    # Check if asset has an active pip infestation
    def has_active_pip_infestation?(asset)
      Incident.pip_infestations.unresolved.exists?(asset: asset)
    end

    # Get the active pip infestation incident
    def active_pip_infestation(asset)
      Incident.pip_infestations.unresolved.find_by(asset: asset)
    end

    # Destroy the asset and return the result
    def destroy_asset(asset)
      message = generate_destruction_message(asset)

      # Mark asset as destroyed
      asset.update!(status: "destroyed")

      # Resolve the pip infestation
      incident = active_pip_infestation(asset)
      incident&.update!(resolved_at: Time.current)

      {
        destroyed: true,
        message: message,
        asset_name: asset.name,
        asset_type: asset.class.name
      }
    end

    # Generate a descriptive destruction message
    def generate_destruction_message(asset)
      catastrophic_endings = [
        "the Pips reached a critical mass and the structure collapsed into a pile of lint",
        "the accumulated Pip waste corroded through the hull, causing catastrophic decompression",
        "the Pips discovered the power core and decided to 'improve' it",
        "the entire asset was converted into a Pip breeding ground and is now structurally unsound",
        "the Pip queen laid eggs in the reactor, which then hatched simultaneously",
        "the Pips achieved sentience and voted to disassemble the asset for 'ethical reasons'",
        "the infestation reached the navigation computer, which then flew into the nearest star",
        "the Pips organized a union and demanded impossible workplace accommodations"
      ]

      "TOTAL LOSS: #{asset.name} has been destroyed - #{catastrophic_endings.sample}"
    end
  end
end
