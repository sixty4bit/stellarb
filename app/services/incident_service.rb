# frozen_string_literal: true

# Service for handling asset failures, pip infestations, and incident management.
# Implements the Catastrophe Mechanic from ROADMAP Section 15.
class IncidentService
  # The 1% Rule - chance that a standard failure becomes a pip infestation
  PIP_OVERRIDE_CHANCE = 0.01

  # Base incident chance per day (modified by chaos factor)
  BASE_INCIDENT_CHANCE = 0.05

  # Repair cost multipliers by severity tier
  REPAIR_COST_MULTIPLIERS = {
    1 => 0.02,  # T1: 2% of asset value
    2 => 0.10,  # T2: 10% of asset value
    3 => 0.25,  # T3: 25% of asset value
    4 => 0.50,  # T4: 50% of asset value
    5 => 0.80   # T5: 80% of asset value (nearly replacement)
  }.freeze

  class << self
    # === The 1% Rule (Pip Factor) ===

    # Check if a standard failure should become a pip infestation
    def pip_override?
      rand < PIP_OVERRIDE_CHANCE
    end

    # === Chaos Factor Correlation ===

    # Check if an incident should occur based on chaos factor
    # Higher chaos = higher chance of incident
    def should_incident?(chaos_factor:)
      # Base chance + chaos modifier
      # At chaos 0: ~5% chance
      # At chaos 50: ~10% chance
      # At chaos 100: ~20% chance
      incident_chance = BASE_INCIDENT_CHANCE + (chaos_factor / 500.0)
      rand < incident_chance
    end

    # === Severity Determination ===

    # Determine severity based on chaos factor
    # High chaos NPCs tend toward higher severity
    def determine_severity(chaos_factor:)
      roll = rand(100)

      # Chaos factor shifts the distribution toward higher severity
      adjusted_roll = roll - (chaos_factor / 4.0)

      case adjusted_roll
      when 80..Float::INFINITY then 1  # T1: Minor Glitch
      when 60..79 then 2               # T2: Component Failure
      when 40..59 then 3               # T3: System Failure
      when 20..39 then 4               # T4: Critical Damage
      else 5                           # T5: Catastrophe
      end
    end

    # === Roll Failure for Asset ===

    # Roll for a potential failure on an asset
    # Returns { incident_occurred: bool, incident: Incident|nil }
    def roll_failure(asset)
      # Get assigned NPC (engineer for ships, staff for buildings)
      npc = get_assigned_npc(asset)
      return { incident_occurred: false } unless npc

      # Check if incident should occur
      unless should_incident?(chaos_factor: npc.chaos_factor)
        return { incident_occurred: false }
      end

      # Determine if it's a pip infestation (1% override)
      is_pip = pip_override?

      # Determine severity
      severity = is_pip ? 5 : determine_severity(chaos_factor: npc.chaos_factor)

      # Generate description
      description = if is_pip
        CatastropheGenerator.generate_pip_description
      else
        CatastropheGenerator.generate_description(severity: severity)
      end

      # Create incident
      incident = Incident.create!(
        asset: asset,
        hired_recruit: npc,
        severity: severity,
        description: description,
        is_pip_infestation: is_pip
      )

      { incident_occurred: true, incident: incident }
    end

    # === Create Pip Infestation (Forced) ===

    # Force a pip infestation on an asset
    def create_pip_infestation(asset)
      npc = get_assigned_npc(asset)

      description = CatastropheGenerator.generate_pip_description
      incident = Incident.create!(
        asset: asset,
        hired_recruit: npc,
        severity: 5,
        description: description,
        is_pip_infestation: true
      )

      { incident: incident }
    end

    # === Remote vs Physical Repair ===

    # Check if an incident can be repaired remotely
    def can_repair_remotely?(incident)
      return false if incident.is_pip_infestation?
      incident.severity <= 2
    end

    # === Purge Command ===

    # Purge pip infestation from asset
    # Requires player to be physically present at the asset's location
    def purge_pips(asset, user, player_location: nil)
      # Find active pip infestation
      pip_incident = asset.incidents.pip_infestations.unresolved.first
      unless pip_incident
        return { success: false, error: "No pip infestation found on this asset" }
      end

      # Check physical presence (player must be at same system as asset)
      asset_location = asset.respond_to?(:current_system) ? asset.current_system : asset.system

      if player_location && player_location != asset_location
        return { success: false, error: "Purging requires physical presence at the asset's location" }
      end

      # Perform the purge
      pip_incident.purge!

      # Generate rewards
      rewards = CatastropheGenerator.purge_rewards

      { success: true, pip_fur: rewards[:pip_fur], incident: pip_incident }
    end

    # === Service Record Queries ===

    # Get incident history for an NPC
    def incident_history_for(npc)
      Incident.for_npc(npc).order(created_at: :desc)
    end

    # Assess risk level of an NPC based on incident history
    def assess_risk(npc)
      incidents = incident_history_for(npc)
      incident_count = incidents.count
      high_severity_count = incidents.where(severity: 4..5).count

      {
        incident_count: incident_count,
        high_severity_count: high_severity_count,
        high_risk: incident_count >= 3 || high_severity_count >= 1,
        risk_score: (incident_count * 10) + (high_severity_count * 25)
      }
    end

    # === Batch Processing ===

    # Process daily failures for all active assets
    def process_daily_failures
      results = { assets_processed: 0, incidents_created: 0 }

      # Process all operational ships
      Ship.operational.find_each do |ship|
        result = roll_failure(ship)
        results[:assets_processed] += 1
        results[:incidents_created] += 1 if result[:incident_occurred]
      end

      # Process all operational buildings
      Building.operational.find_each do |building|
        result = roll_failure(building)
        results[:assets_processed] += 1
        results[:incidents_created] += 1 if result[:incident_occurred]
      end

      results
    end

    # === Recovery Cost ===

    # Calculate repair cost for an incident
    def calculate_repair_cost(severity:, asset_value:)
      multiplier = REPAIR_COST_MULTIPLIERS[severity] || 0.5
      (asset_value * multiplier).round
    end

    private

    # Get the assigned NPC for an asset (preferring engineers)
    def get_assigned_npc(asset)
      hirings = asset.hirings.where(status: "active")

      # Prefer engineer class for failure responsibility
      engineer_hiring = hirings.joins(:hired_recruit)
        .where(hired_recruits: { npc_class: "engineer" })
        .first

      return engineer_hiring.hired_recruit if engineer_hiring

      # Fall back to any active assignment
      hirings.first&.hired_recruit
    end
  end
end
