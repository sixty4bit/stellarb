# frozen_string_literal: true

require "test_helper"

class PirateEncounterJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @cradle = systems(:cradle)
    @alpha_centauri = systems(:alpha_centauri)

    # Create a high-hazard system for testing
    @dangerous_system = System.create!(
      name: "Pirate Haven",
      short_id: "sy-pir",
      x: 950,
      y: 950,
      z: 950,
      properties: {
        "star_type" => "red_giant",
        "planet_count" => 2,
        "hazard_level" => 80
      }
    )

    @ship = Ship.create!(
      user: @user,
      name: "Test Freighter",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100, "copper" => 50, "water" => 30 }
    )
  end

  # ===========================================
  # Safe Zone Tests
  # ===========================================

  test "skips encounter in The Cradle (hazard level 0)" do
    @ship.update!(current_system: @cradle)

    result = PirateEncounterJob.perform_now(@ship)

    assert_equal :safe_zone, result[:outcome]
    assert_equal "The Cradle is a safe zone", result[:reason]
  end

  test "skips encounter when arrived via warp gate" do
    # Create a warp gate to the dangerous system
    origin = System.create!(
      name: "Gate Hub",
      short_id: "sy-hub",
      x: 940,
      y: 940,
      z: 940,
      properties: { "hazard_level" => 30 }
    )

    WarpGate.create!(
      system_a: origin,
      system_b: @dangerous_system
    )

    result = PirateEncounterJob.perform_now(@ship, arrived_via_warp: true)

    assert_equal :safe_zone, result[:outcome]
    assert_equal "Warp gate travel is protected", result[:reason]
  end

  # ===========================================
  # Encounter Chance Tests
  # ===========================================

  test "encounter chance scales with hazard level" do
    # Low hazard system - 15%
    low_hazard = System.create!(
      name: "Low Hazard",
      short_id: "sy-low",
      x: 920,
      y: 920,
      z: 920,
      properties: { "hazard_level" => 15 }
    )

    # High hazard system - 80%
    high_hazard = @dangerous_system

    low_chance = PirateEncounterJob.encounter_chance_for(low_hazard)
    high_chance = PirateEncounterJob.encounter_chance_for(high_hazard)

    assert low_chance < high_chance
    assert_in_delta 0.15, low_chance, 0.05  # ~15% for hazard 15
    assert_in_delta 0.80, high_chance, 0.10 # ~80% for hazard 80
  end

  test "no encounter when roll exceeds chance" do
    # Stub the random roll to always exceed encounter chance
    PirateEncounterJob.define_singleton_method(:random_roll) { 1.0 }

    result = PirateEncounterJob.perform_now(@ship)
    assert_equal :no_encounter, result[:outcome]
  ensure
    # Restore original method
    PirateEncounterJob.define_singleton_method(:random_roll) { rand }
  end

  # ===========================================
  # Marine Defense Tests
  # ===========================================

  test "marines reduce encounter chance" do
    base_chance = PirateEncounterJob.encounter_chance_for(@dangerous_system)

    # Assign a marine to the ship
    marine_recruit = create_marine_for_ship(@ship, skill: 80)

    reduced_chance = PirateEncounterJob.encounter_chance_for(
      @dangerous_system,
      marine_skill: marine_recruit.skill
    )

    assert reduced_chance < base_chance
    # Skill 80 marine should reduce by ~20%
    assert_in_delta base_chance * 0.8, reduced_chance, 0.1
  end

  test "marines improve combat outcome (repelled when roll > 150)" do
    marine_recruit = create_marine_for_ship(@ship, skill: 90)
    original_cargo = @ship.cargo.deep_dup
    original_hull = @ship.ship_attributes["hull_points"]

    # Force encounter and simulate high marine roll
    stub_random_and_marine_roll(random: 0.0, marine: 175) do
      result = PirateEncounterJob.perform_now(@ship)

      assert_equal :repelled, result[:outcome]
      @ship.reload
      assert_equal original_cargo, @ship.cargo
      assert_equal original_hull, @ship.ship_attributes["hull_points"]
    end
  end

  test "escaped outcome loses 5-15% cargo and 5-10% damage" do
    # Use non-Vex ship (Vex has 15% cargo protection which negates escaped losses)
    solari_ship = Ship.create!(
      user: @user,
      name: "Solari Scout",
      race: "solari",
      hull_size: "scout",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100, "copper" => 50, "water" => 30 }
    )

    marine_recruit = create_marine_for_ship(solari_ship, skill: 70)
    original_cargo_total = solari_ship.total_cargo_weight
    original_hull = solari_ship.ship_attributes["hull_points"]

    # Force encounter and simulate escaped roll (100-150)
    stub_random_and_marine_roll(random: 0.0, marine: 120) do
      result = PirateEncounterJob.perform_now(solari_ship)

      assert_equal :escaped, result[:outcome]
      solari_ship.reload

      # 5-15% cargo lost
      cargo_lost = original_cargo_total - solari_ship.total_cargo_weight
      cargo_lost_pct = cargo_lost.to_f / original_cargo_total
      assert_in_delta 0.10, cargo_lost_pct, 0.06

      # 5-10% hull damage
      hull_lost = original_hull - solari_ship.ship_attributes["hull_points"]
      hull_lost_pct = hull_lost.to_f / original_hull
      assert_in_delta 0.075, hull_lost_pct, 0.03
    end
  end

  test "raided outcome loses 20-40% cargo and 15-30% damage" do
    # Use non-Vex ship for accurate loss testing
    myrmidon_ship = Ship.create!(
      user: @user,
      name: "Myrmidon Hauler",
      race: "myrmidon",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100, "copper" => 50, "water" => 30 }
    )

    original_cargo_total = myrmidon_ship.total_cargo_weight
    original_hull = myrmidon_ship.ship_attributes["hull_points"]

    # No marine - simulate raided roll (50-100)
    stub_random_and_marine_roll(random: 0.0, marine: 75) do
      result = PirateEncounterJob.perform_now(myrmidon_ship)

      assert_equal :raided, result[:outcome]
      myrmidon_ship.reload

      # 20-40% cargo lost
      cargo_lost = original_cargo_total - myrmidon_ship.total_cargo_weight
      cargo_lost_pct = cargo_lost.to_f / original_cargo_total
      assert_in_delta 0.30, cargo_lost_pct, 0.11

      # 15-30% hull damage
      hull_lost = original_hull - myrmidon_ship.ship_attributes["hull_points"]
      hull_lost_pct = hull_lost.to_f / original_hull
      assert_in_delta 0.225, hull_lost_pct, 0.08
    end
  end

  test "devastated outcome loses 50-80% cargo and 40-60% damage" do
    # Use non-Vex ship for accurate loss testing
    solari_freighter = Ship.create!(
      user: @user,
      name: "Solari Freighter",
      race: "solari",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100, "copper" => 50, "water" => 30 }
    )

    original_cargo_total = solari_freighter.total_cargo_weight
    original_hull = solari_freighter.ship_attributes["hull_points"]

    # No marine - simulate devastated roll (<=50)
    stub_random_and_marine_roll(random: 0.0, marine: 30) do
      result = PirateEncounterJob.perform_now(solari_freighter)

      assert_equal :devastated, result[:outcome]
      solari_freighter.reload

      # 50-80% cargo lost
      cargo_lost = original_cargo_total - solari_freighter.total_cargo_weight
      cargo_lost_pct = cargo_lost.to_f / original_cargo_total
      assert_in_delta 0.65, cargo_lost_pct, 0.16

      # 40-60% hull damage
      hull_lost = original_hull - solari_freighter.ship_attributes["hull_points"]
      hull_lost_pct = hull_lost.to_f / original_hull
      assert_in_delta 0.50, hull_lost_pct, 0.11
    end
  end

  # ===========================================
  # Notification Tests
  # ===========================================

  test "sends inbox notification after encounter" do
    stub_random_and_marine_roll(random: 0.0, marine: 75) do
      assert_difference -> { Message.count }, 1 do
        PirateEncounterJob.perform_now(@ship)
      end

      message = Message.last
      assert_equal @user, message.user
      assert_includes message.title, "Pirate"
      assert_equal "combat", message.category
    end
  end

  test "no notification when no encounter" do
    PirateEncounterJob.define_singleton_method(:random_roll) { 1.0 }

    assert_no_difference -> { Message.count } do
      PirateEncounterJob.perform_now(@ship)
    end
  ensure
    PirateEncounterJob.define_singleton_method(:random_roll) { rand }
  end

  # ===========================================
  # Racial Ship Bonuses
  # ===========================================

  test "krog ships take less hull damage (higher hull)" do
    krog_ship = Ship.create!(
      user: @user,
      name: "Krog Warship",
      race: "krog",
      hull_size: "cruiser",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100 }
    )

    original_hull = krog_ship.ship_attributes["hull_points"]

    stub_random_and_marine_roll(random: 0.0, marine: 30) do
      result = PirateEncounterJob.perform_now(krog_ship)

      krog_ship.reload
      hull_remaining_pct = krog_ship.ship_attributes["hull_points"].to_f / original_hull

      # Even after devastating attack, Krog survives better
      assert hull_remaining_pct >= 0.4, "Krog ship should have at least 40% hull remaining"
    end
  end

  test "vex ships protect some cargo via hidden compartments" do
    vex_ship = Ship.create!(
      user: @user,
      name: "Vex Smuggler",
      race: "vex",
      hull_size: "transport",
      variant_idx: 0,
      fuel: 100,
      current_system: @dangerous_system,
      status: "docked",
      cargo: { "iron" => 100, "luxury_goods" => 50 }
    )

    original_cargo = vex_ship.total_cargo_weight

    stub_random_and_marine_roll(random: 0.0, marine: 30) do
      result = PirateEncounterJob.perform_now(vex_ship)

      vex_ship.reload
      cargo_remaining_pct = vex_ship.total_cargo_weight.to_f / original_cargo

      # Vex hidden compartments protect 15% of cargo
      # Devastated loses 50-80%, so Vex should have 20-50% + 15% = 35-65%
      assert cargo_remaining_pct >= 0.25, "Vex ship should retain more cargo via hidden compartments"
    end
  end

  # ===========================================
  # Edge Cases
  # ===========================================

  test "handles ship with no cargo gracefully" do
    @ship.update!(cargo: {})

    stub_random_and_marine_roll(random: 0.0, marine: 75) do
      result = PirateEncounterJob.perform_now(@ship)

      assert_equal :raided, result[:outcome]
      assert_equal 0, result[:cargo_lost]
    end
  end

  test "ship is not destroyed even at maximum damage" do
    @ship.ship_attributes["hull_points"] = 10  # Very low hull
    @ship.save!

    stub_random_and_marine_roll(random: 0.0, marine: 30) do
      result = PirateEncounterJob.perform_now(@ship)

      @ship.reload
      # Ship survives but is severely damaged
      assert @ship.ship_attributes["hull_points"] >= 1
      assert_equal "docked", @ship.status  # Not destroyed
    end
  end

  private

  def create_marine_for_ship(ship, skill:)
    hired_recruit = HiredRecruit.create!(
      race: "krog",
      npc_class: "marine",
      skill: skill,
      chaos_factor: 10,
      stats: { "combat" => skill }
    )

    hiring = Hiring.create!(
      user: ship.user,
      hired_recruit: hired_recruit,
      wage: hired_recruit.calculate_wage,
      assignable: ship,
      hired_at: Time.current,
      status: "active"
    )

    hired_recruit
  end

  def stub_random_and_marine_roll(random:, marine:)
    original_random = PirateEncounterJob.method(:random_roll)
    original_marine = PirateEncounterJob.method(:marine_roll)

    PirateEncounterJob.define_singleton_method(:random_roll) { random }
    PirateEncounterJob.define_singleton_method(:marine_roll) { |_skill = 0| marine }

    yield
  ensure
    PirateEncounterJob.define_singleton_method(:random_roll, original_random)
    PirateEncounterJob.define_singleton_method(:marine_roll, original_marine)
  end
end
