# frozen_string_literal: true

require "test_helper"

class PipDamageServiceTest < ActiveSupport::TestCase
  setup do
    # Clean slate
    Route.delete_all
    Incident.delete_all
    Hiring.delete_all
    Ship.delete_all
    Building.delete_all

    @user = User.create!(name: "Test User #{SecureRandom.hex(4)}", email: "test#{SecureRandom.hex(4)}@example.com", credits: 10000)
    @system = System.create!(
      name: "Test System",
      x: 3, y: 6, z: 9,
      discovered_by: @user
    )
    @ship = Ship.create!(
      name: "Yamato",
      user: @user,
      race: "vex",
      hull_size: "transport",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @system
    )
    @building = Building.create!(
      name: "Refinery Alpha",
      user: @user,
      system: @system,
      race: "krog",
      function: "defense",
      tier: 2
    )
  end

  # === Output Reduction ===

  test "pip infestation reduces building output by 100% (disabled)" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true
    )

    modifier = PipDamageService.output_modifier(@building)

    assert_equal 0, modifier, "Pip-infested building should have 0 output"
  end

  test "pip infestation reduces ship efficiency by 100% (disabled)" do
    incident = Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true
    )

    modifier = PipDamageService.output_modifier(@ship)

    assert_equal 0, modifier, "Pip-infested ship should have 0 efficiency"
  end

  test "unaffected assets have normal output" do
    modifier = PipDamageService.output_modifier(@building)

    assert_equal 1.0, modifier, "Unaffected building should have normal output"
  end

  test "resolved pip infestation restores normal output" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      resolved_at: Time.current
    )

    modifier = PipDamageService.output_modifier(@building)

    assert_equal 1.0, modifier, "Resolved pip infestation should restore normal output"
  end

  # === Maintenance Increase ===

  test "pip infestation increases maintenance cost" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 3.days.ago  # Needs some age for maintenance to increase
    )

    modifier = PipDamageService.maintenance_modifier(@building)

    assert modifier > 1.0, "Pip-infested building should have increased maintenance"
  end

  test "maintenance increases with infestation duration" do
    # Recent infestation
    recent = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 1.day.ago
    )

    recent_modifier = PipDamageService.maintenance_modifier(@building)

    # Clean up
    recent.destroy!

    # Older infestation
    old = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 10.days.ago
    )

    old_modifier = PipDamageService.maintenance_modifier(@building)

    assert old_modifier > recent_modifier, "Longer infestations should have higher maintenance"
  end

  test "unaffected assets have normal maintenance" do
    modifier = PipDamageService.maintenance_modifier(@building)

    assert_equal 1.0, modifier, "Unaffected building should have normal maintenance"
  end

  # === Destruction Risk ===

  test "long-standing infestation has destruction risk" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 30.days.ago
    )

    risk = PipDamageService.destruction_risk(@building)

    assert risk > 0, "30-day infestation should have destruction risk"
  end

  test "new infestation has no destruction risk" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 1.day.ago
    )

    risk = PipDamageService.destruction_risk(@building)

    assert_equal 0, risk, "New infestation should have no destruction risk"
  end

  test "destruction risk increases with duration" do
    # Create an old infestation
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 14.days.ago
    )

    risk_14_days = PipDamageService.destruction_risk(@building)

    # Update to be older
    incident.update!(created_at: 28.days.ago)

    risk_28_days = PipDamageService.destruction_risk(@building)

    assert risk_28_days > risk_14_days, "Longer infestations should have higher destruction risk"
  end

  test "unaffected assets have no destruction risk" do
    risk = PipDamageService.destruction_risk(@building)

    assert_equal 0, risk, "Unaffected building should have no destruction risk"
  end

  # === Damage Summary ===

  test "returns comprehensive damage summary" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 7.days.ago
    )

    summary = PipDamageService.damage_summary(@building)

    assert_kind_of Hash, summary
    assert summary.key?(:infested)
    assert summary.key?(:output_modifier)
    assert summary.key?(:maintenance_modifier)
    assert summary.key?(:destruction_risk)
    assert summary.key?(:days_infested)

    assert summary[:infested] == true
    assert_equal 7, summary[:days_infested]
  end

  # === Destruction Processing ===

  test "process_destruction destroys asset if random roll triggers" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 60.days.ago
    )

    # Force destruction
    original_method = PipDamageService.method(:should_destroy?)
    PipDamageService.define_singleton_method(:should_destroy?) { |_| true }

    begin
      result = PipDamageService.process_potential_destruction(@building)

      assert result[:destroyed] == true
      @building.reload
      assert_equal "destroyed", @building.status
    ensure
      PipDamageService.define_singleton_method(:should_destroy?, original_method)
    end
  end

  test "destruction creates appropriate message" do
    incident = Incident.create!(
      asset: @building,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 60.days.ago
    )

    # Force destruction
    original_method = PipDamageService.method(:should_destroy?)
    PipDamageService.define_singleton_method(:should_destroy?) { |_| true }

    begin
      result = PipDamageService.process_potential_destruction(@building)

      assert result[:message].present?
      assert result[:message].include?("Pip") || result[:message].include?("pip")
    ensure
      PipDamageService.define_singleton_method(:should_destroy?, original_method)
    end
  end
end
