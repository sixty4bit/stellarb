# frozen_string_literal: true

# Simulates NPC pirate encounters when a ship arrives at a system.
# Part of the money/cargo sink system - creates demand for Marines.
#
# Called by Ship#check_arrival! after a ship completes travel.
# Safe zones (The Cradle, warp gate arrivals) bypass encounters.
#
# Encounter outcomes based on Marine skill roll:
#   - Repelled (>150): No losses
#   - Escaped (>100): 5-15% cargo, 5-10% damage
#   - Raided (>50): 20-40% cargo, 15-30% damage
#   - Devastated (≤50): 50-80% cargo, 40-60% damage
class PirateEncounterJob < ApplicationJob
  queue_as :default

  # Outcome thresholds for marine roll
  REPELLED_THRESHOLD = 150
  ESCAPED_THRESHOLD = 100
  RAIDED_THRESHOLD = 50

  # Cargo loss percentages [min, max]
  CARGO_LOSS = {
    escaped: [0.05, 0.15],
    raided: [0.20, 0.40],
    devastated: [0.50, 0.80]
  }.freeze

  # Hull damage percentages [min, max]
  HULL_DAMAGE = {
    escaped: [0.05, 0.10],
    raided: [0.15, 0.30],
    devastated: [0.40, 0.60]
  }.freeze

  # Racial bonuses
  VEX_CARGO_PROTECTION = 0.15  # Hidden compartments protect 15%
  KROG_DAMAGE_REDUCTION = 0.20 # Reinforced hull reduces damage by 20%

  # Calculate encounter chance for a system
  # @param system [System] The system to check
  # @param marine_skill [Integer, nil] Skill of assigned marine (reduces chance)
  # @return [Float] Probability of encounter (0.0 to 1.0)
  def self.encounter_chance_for(system, marine_skill: nil)
    hazard = system.properties&.dig("hazard_level") || 0
    base_chance = hazard / 100.0

    # Marines reduce encounter chance by up to 25% at skill 100
    if marine_skill && marine_skill > 0
      reduction = (marine_skill / 100.0) * 0.25
      base_chance *= (1.0 - reduction)
    end

    base_chance.clamp(0.0, 1.0)
  end

  # Stub-friendly random roll (0.0 to 1.0)
  def self.random_roll
    rand
  end

  # Stub-friendly marine combat roll (0-200 range)
  # Base roll is 50, marine skill adds up to 150
  def self.marine_roll(marine_skill = 0)
    base = 50
    skill_bonus = (marine_skill || 0)
    variance = rand(-20..20)
    base + skill_bonus + variance
  end

  # @param ship [Ship] The ship to check for pirate encounters
  # @param arrived_via_warp [Boolean] Whether ship arrived via warp gate (protected)
  # @param force_encounter [Float, nil] Override random roll for testing (0.0 = always encounter)
  # @param force_marine_roll [Integer, nil] Override marine combat roll for testing
  def perform(ship, arrived_via_warp: false, force_encounter: nil, force_marine_roll: nil)
    system = ship.current_system
    return safe_zone_result("Ship has no current system") unless system

    # Check safe zones
    if system_is_safe?(system)
      return safe_zone_result("The Cradle is a safe zone")
    end

    if arrived_via_warp
      return safe_zone_result("Warp gate travel is protected")
    end

    # Get marine skill if one is assigned
    marine_skill = assigned_marine_skill(ship)
    encounter_chance = self.class.encounter_chance_for(system, marine_skill: marine_skill)

    # Roll for encounter (use forced value for testing, or random)
    encounter_roll = force_encounter || self.class.random_roll
    if encounter_roll >= encounter_chance
      return { outcome: :no_encounter, chance: encounter_chance }
    end

    # Combat roll determines outcome (use forced value for testing, or random)
    roll = force_marine_roll || self.class.marine_roll(marine_skill)
    outcome = determine_outcome(roll)

    # Apply losses based on outcome
    result = apply_outcome(ship, outcome)

    # Send notification
    send_pirate_notification(ship, outcome, result)

    result.merge(
      outcome: outcome,
      roll: roll,
      marine_skill: marine_skill
    )
  end

  private

  def system_is_safe?(system)
    # The Cradle (hazard 0) is always safe
    hazard = system.properties&.dig("hazard_level") || 0
    hazard == 0
  end

  def safe_zone_result(reason)
    { outcome: :safe_zone, reason: reason }
  end

  def assigned_marine_skill(ship)
    marine = ship.crew.joins(:hirings)
                 .where(hirings: { status: "active" })
                 .where(npc_class: "marine")
                 .order(skill: :desc)
                 .first

    marine&.skill || 0
  end

  def determine_outcome(roll)
    if roll > REPELLED_THRESHOLD
      :repelled
    elsif roll > ESCAPED_THRESHOLD
      :escaped
    elsif roll > RAIDED_THRESHOLD
      :raided
    else
      :devastated
    end
  end

  def apply_outcome(ship, outcome)
    return { cargo_lost: 0, damage_taken: 0 } if outcome == :repelled

    cargo_lost = apply_cargo_loss(ship, outcome)
    damage_taken = apply_hull_damage(ship, outcome)

    { cargo_lost: cargo_lost, damage_taken: damage_taken }
  end

  def apply_cargo_loss(ship, outcome)
    return 0 if ship.total_cargo_weight == 0

    range = CARGO_LOSS[outcome]
    loss_pct = rand(range[0]..range[1])

    # Vex hidden compartments protect cargo
    if ship.race == "vex"
      loss_pct = [loss_pct - VEX_CARGO_PROTECTION, 0].max
    end

    total_to_lose = (ship.total_cargo_weight * loss_pct).round
    actual_lost = distribute_cargo_loss(ship, total_to_lose)

    ship.save!
    actual_lost
  end

  def distribute_cargo_loss(ship, total_to_lose)
    remaining = total_to_lose
    cargo = ship.cargo || {}

    # Lose cargo proportionally from each commodity
    cargo.each do |commodity, quantity|
      next if remaining <= 0 || quantity <= 0

      proportion = quantity.to_f / ship.total_cargo_weight
      to_lose = (total_to_lose * proportion).round
      to_lose = [to_lose, quantity, remaining].min

      cargo[commodity] = quantity - to_lose
      remaining -= to_lose
    end

    # Clean up empty cargo entries
    ship.cargo = cargo.reject { |_, v| v <= 0 }

    total_to_lose - remaining
  end

  def apply_hull_damage(ship, outcome)
    current_hull = ship.ship_attributes["hull_points"] || 100

    range = HULL_DAMAGE[outcome]
    damage_pct = rand(range[0]..range[1])

    # Krog reinforced hulls take less damage
    if ship.race == "krog"
      damage_pct *= (1.0 - KROG_DAMAGE_REDUCTION)
    end

    damage = (current_hull * damage_pct).round
    new_hull = [current_hull - damage, 1].max  # Never destroy ship

    ship.ship_attributes["hull_points"] = new_hull
    ship.save!

    damage
  end

  def send_pirate_notification(ship, outcome, result)
    title = pirate_notification_title(outcome)
    body = pirate_notification_body(ship, outcome, result)

    Message.create!(
      user: ship.user,
      title: title,
      body: body,
      from: "Security Alert",
      category: "combat",
      urgent: outcome == :devastated
    )
  end

  def pirate_notification_title(outcome)
    case outcome
    when :repelled
      "⚔️ Pirates Repelled!"
    when :escaped
      "🏃 Narrow Escape from Pirates"
    when :raided
      "💀 Pirate Raid on Your Ship"
    when :devastated
      "🔥 Devastating Pirate Attack!"
    end
  end

  def pirate_notification_body(ship, outcome, result)
    lines = ["Your ship #{ship.name} encountered pirates in #{ship.current_system.name}."]

    case outcome
    when :repelled
      lines << "\nYour marines successfully repelled the attack with no losses!"
    when :escaped
      lines << "\nYou managed to escape, but not without cost:"
      lines << "• Cargo lost: #{result[:cargo_lost]} units"
      lines << "• Hull damage: #{result[:damage_taken]} points"
    when :raided
      lines << "\nThe pirates overwhelmed your defenses:"
      lines << "• Cargo lost: #{result[:cargo_lost]} units"
      lines << "• Hull damage: #{result[:damage_taken]} points"
      lines << "\nConsider hiring marines to improve your ship's defense."
    when :devastated
      lines << "\n⚠️ CRITICAL: Your ship was devastated by the attack!"
      lines << "• Cargo lost: #{result[:cargo_lost]} units"
      lines << "• Hull damage: #{result[:damage_taken]} points"
      lines << "\nYour ship needs immediate repairs. Consider avoiding high-hazard systems without marine protection."
    end

    lines.join("\n")
  end
end
