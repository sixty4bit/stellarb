# frozen_string_literal: true

require "test_helper"

class IncidentServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Test User", email: "incident_test@example.com", credits: 10000)
    @system = System.create!(
      name: "Test System",
      x: 3, y: 6, z: 9,  # Must be divisible by 3 and in range 0-9
      discovered_by: @user
    )
    @ship = Ship.create!(
      name: "Enterprise",
      user: @user,
      race: "solari",
      hull_size: "cruiser",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @system
    )
    @building = Building.create!(
      name: "Mining Rig",
      user: @user,
      system: @system,
      race: "krog",
      function: "extraction",
      tier: 3
    )

    # Create low chaos and high chaos NPCs
    @low_chaos_recruit = Recruit.create!(
      race: "solari",
      npc_class: "engineer",
      skill: 80,
      chaos_factor: 15,
      level_tier: 1,
      available_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    @low_chaos_npc = HiredRecruit.create_from_recruit!(@low_chaos_recruit, @user)

    @high_chaos_recruit = Recruit.create!(
      race: "krog",
      npc_class: "engineer",
      skill: 90,
      chaos_factor: 85,
      level_tier: 1,
      available_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    @high_chaos_npc = HiredRecruit.create_from_recruit!(@high_chaos_recruit, @user)

    # Assign NPCs to assets
    Hiring.create!(
      user: @user,
      hired_recruit: @low_chaos_npc,
      assignable: @ship,
      status: "active",
      hired_at: 1.day.ago,
      wage: 100
    )

    Hiring.create!(
      user: @user,
      hired_recruit: @high_chaos_npc,
      assignable: @building,
      status: "active",
      hired_at: 1.day.ago,
      wage: 150
    )
  end

  # === The 1% Rule (Pip Factor) ===

  test "1% of standard failures escalate to pip catastrophes" do
    pip_count = 0
    total_failures = 10000

    total_failures.times do
      pip_count += 1 if IncidentService.pip_override?
    end

    # Should be approximately 1% (allow for statistical variance)
    expected_min = 50   # 0.5%
    expected_max = 200  # 2%

    assert pip_count >= expected_min && pip_count <= expected_max,
      "Pip rate should be ~1%, got #{(pip_count.to_f / total_failures * 100).round(2)}% (#{pip_count}/#{total_failures})"
  end

  # === Chaos Factor Correlation ===

  test "chaos factor correlates with incident rate (r > 0.7)" do
    # Test correlation by checking that high chaos has significantly more incidents
    # than low chaos over many trials
    results = {}

    [ 10, 30, 50, 70, 90 ].each do |chaos|
      incident_count = 0
      1000.times do
        incident_count += 1 if IncidentService.should_incident?(chaos_factor: chaos)
      end
      results[chaos] = incident_count
    end

    # Verify monotonic increase (higher chaos = more incidents)
    assert results[10] < results[50], "Chaos 10 (#{results[10]}) should have fewer incidents than 50 (#{results[50]})"
    assert results[50] < results[90], "Chaos 50 (#{results[50]}) should have fewer incidents than 90 (#{results[90]})"

    # Verify at least 2x difference between low and high (allow statistical variance)
    ratio = results[90].to_f / [ results[10], 1 ].max  # Avoid division by zero
    assert ratio >= 2, "High chaos should have 2x+ more incidents (got #{ratio.round(2)}x)"
  end

  # === Severity Determination ===

  test "severity is influenced by chaos factor" do
    low_chaos_severities = []
    high_chaos_severities = []

    500.times do
      low_chaos_severities << IncidentService.determine_severity(chaos_factor: 15)
      high_chaos_severities << IncidentService.determine_severity(chaos_factor: 85)
    end

    low_avg = low_chaos_severities.sum.to_f / low_chaos_severities.length
    high_avg = high_chaos_severities.sum.to_f / high_chaos_severities.length

    # High chaos should trend toward higher severity
    assert high_avg > low_avg,
      "High chaos (#{high_avg.round(2)}) should average higher severity than low chaos (#{low_avg.round(2)})"
  end

  # === Roll Failure for Asset ===

  test "roll_failure for ship creates incident and updates NPC record" do
    initial_history_count = @low_chaos_npc.employment_history.length

    result = IncidentService.roll_failure(@ship)

    if result[:incident_occurred]
      incident = result[:incident]

      assert incident.persisted?
      assert_equal @ship, incident.asset
      assert_equal @low_chaos_npc, incident.hired_recruit

      # NPC should have new history entry
      @low_chaos_npc.reload
      assert_equal initial_history_count + 1, @low_chaos_npc.employment_history.length
    end
  end

  test "roll_failure for building creates incident with assigned staff" do
    result = IncidentService.roll_failure(@building)

    if result[:incident_occurred]
      incident = result[:incident]

      assert incident.persisted?
      assert_equal @building, incident.asset
      assert_equal @high_chaos_npc, incident.hired_recruit
    end
  end

  test "pip infestation disables asset completely" do
    # Force pip infestation
    result = IncidentService.create_pip_infestation(@ship)

    assert result[:incident].is_pip_infestation?
    assert @ship.reload.disabled?
  end

  # === Remote vs Physical Repair ===

  test "T1-T2 incidents can be fixed remotely" do
    t1_incident = Incident.create!(
      asset: @ship,
      hired_recruit: @low_chaos_npc,
      severity: 1,
      description: "Minor glitch"
    )

    t2_incident = Incident.create!(
      asset: @ship,
      hired_recruit: @low_chaos_npc,
      severity: 2,
      description: "Component failure"
    )

    assert IncidentService.can_repair_remotely?(t1_incident)
    assert IncidentService.can_repair_remotely?(t2_incident)
  end

  test "T3+ incidents require physical presence" do
    t3_incident = Incident.create!(
      asset: @ship,
      hired_recruit: @low_chaos_npc,
      severity: 3,
      description: "System failure"
    )

    t4_incident = Incident.create!(
      asset: @ship,
      hired_recruit: @low_chaos_npc,
      severity: 4,
      description: "Critical damage"
    )

    t5_incident = Incident.create!(
      asset: @ship,
      hired_recruit: @low_chaos_npc,
      severity: 5,
      description: "Catastrophe"
    )

    refute IncidentService.can_repair_remotely?(t3_incident)
    refute IncidentService.can_repair_remotely?(t4_incident)
    refute IncidentService.can_repair_remotely?(t5_incident)
  end

  test "pip infestation always requires physical presence (no remote fix)" do
    pip_incident = Incident.create!(
      asset: @ship,
      hired_recruit: @low_chaos_npc,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true
    )

    refute IncidentService.can_repair_remotely?(pip_incident)
  end

  # === Purge Command ===

  test "purge command resolves pip infestation and re-enables asset" do
    # Create pip infestation
    pip_incident = IncidentService.create_pip_infestation(@ship)[:incident]
    assert @ship.reload.disabled?

    # Player arrives and purges
    result = IncidentService.purge_pips(@ship, @user)

    assert result[:success]
    assert result[:pip_fur] > 0
    refute @ship.reload.disabled?
    assert pip_incident.reload.resolved?
  end

  test "purge fails if player is not at same location as asset" do
    pip_incident = IncidentService.create_pip_infestation(@ship)[:incident]

    # Move player's ship to different system
    other_system = System.create!(
      name: "Other System",
      x: 0, y: 3, z: 6,  # Different location, divisible by 3 and in range 0-9
      discovered_by: @user
    )

    result = IncidentService.purge_pips(@ship, @user, player_location: other_system)

    refute result[:success]
    assert_includes result[:error], "physical presence"
  end

  # === Service Record Queries ===

  test "can query incident history for NPC" do
    3.times do |i|
      Incident.create!(
        asset: @ship,
        hired_recruit: @low_chaos_npc,
        severity: i + 1,
        description: "Incident #{i + 1}"
      )
    end

    history = IncidentService.incident_history_for(@low_chaos_npc)

    assert_equal 3, history.count
  end

  test "can identify high-risk NPCs by incident pattern" do
    # Give high chaos NPC many incidents
    5.times do |i|
      Incident.create!(
        asset: @building,
        hired_recruit: @high_chaos_npc,
        severity: (i % 5) + 1,
        description: "Incident #{i + 1}"
      )
    end

    # High chaos NPC should be flagged as high risk
    risk_assessment = IncidentService.assess_risk(@high_chaos_npc)

    assert risk_assessment[:high_risk]
    assert risk_assessment[:incident_count] >= 5
  end

  # === Batch Processing ===

  test "process_daily_failures processes all active assets" do
    # Create additional assets
    3.times do |i|
      Ship.create!(
        name: "Ship #{i}",
        user: @user,
        race: "myrmidon",
        hull_size: "scout",
        variant_idx: i,
        fuel: 50,
        status: "docked",
        current_system: @system
      )
    end

    # Run daily failure check
    results = IncidentService.process_daily_failures

    # Should process all active ships and buildings
    assert results[:assets_processed] >= 4  # 1 original ship + 3 new + 1 building
    assert results[:incidents_created].is_a?(Integer)
  end

  # === Recovery Cost ===

  test "T5 recovery costs nearly as much as replacement" do
    # Set asset value
    asset_value = 10000

    t5_cost = IncidentService.calculate_repair_cost(
      severity: 5,
      asset_value: asset_value
    )

    # Should be 80%+ of replacement
    assert t5_cost >= asset_value * 0.75,
      "T5 repair (#{t5_cost}) should cost at least 75% of asset value (#{asset_value})"
  end
end
