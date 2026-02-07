# frozen_string_literal: true

require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Test User", email: "test@example.com", credits: 10000)
    @system = System.create!(
      name: "Test System",
      x: 3, y: 6, z: 9,  # Must be divisible by 3
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
    @recruit = Recruit.create!(
      race: "vex",
      npc_class: "engineer",
      skill: 75,
      chaos_factor: 50,
      level_tier: 1,
      available_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    @hired_recruit = HiredRecruit.create_from_recruit!(@recruit, @user)
  end

  # === Severity Tiers (T1-T5) ===

  test "T1 incident: minor glitch with 5% functionality loss" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 1,
      description: "Sensors misalignment",
      is_pip_infestation: false
    )

    assert_equal 1, incident.severity
    assert_equal 5, incident.functionality_loss_percent
    assert_equal "minor_glitch", incident.severity_tier_name
    assert incident.auto_resolvable?
  end

  test "T2 incident: component failure with 15% functionality loss" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Power coupling fused",
      is_pip_infestation: false
    )

    assert_equal 2, incident.severity
    assert_equal 15, incident.functionality_loss_percent
    assert_equal "component_failure", incident.severity_tier_name
    refute incident.auto_resolvable?
  end

  test "T3 incident: system failure with 35% functionality loss" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 3,
      description: "Reactor coolant leak",
      is_pip_infestation: false
    )

    assert_equal 3, incident.severity
    assert_equal 35, incident.functionality_loss_percent
    assert_equal "system_failure", incident.severity_tier_name
    refute incident.remote_fixable?
  end

  test "T4 incident: critical damage with 50% functionality loss" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 4,
      description: "Hull breach",
      is_pip_infestation: false
    )

    assert_equal 4, incident.severity
    assert_equal 50, incident.functionality_loss_percent
    assert_equal "critical_damage", incident.severity_tier_name
    assert incident.requires_physical_presence?
  end

  test "T5 incident: catastrophe with 80% functionality loss" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 5,
      description: "Engine explosion",
      is_pip_infestation: false
    )

    assert_equal 5, incident.severity
    assert_equal 80, incident.functionality_loss_percent
    assert_equal "catastrophe", incident.severity_tier_name
    assert incident.requires_physical_presence?
    assert incident.nearly_total_loss?
  end

  # === Pip Infestation ===

  test "pip infestation always requires physical presence to purge" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 5,
      description: "Pip infestation: Laser Battery 1 is offline.",
      is_pip_infestation: true
    )

    assert incident.is_pip_infestation?
    assert incident.requires_physical_presence?
    refute incident.remote_fixable?
  end

  test "pip infestation disables asset completely" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true
    )

    # Asset should be disabled
    assert_equal 100, incident.functionality_loss_percent  # Total loss for pip
    assert @ship.reload.disabled?
  end

  test "purging pip infestation restores asset" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true
    )

    assert @ship.reload.disabled?

    # Purge the infestation
    incident.purge!

    assert incident.resolved?
    refute @ship.reload.disabled?
    assert incident.resolved_at.present?
  end

  # === Service Record / Employment History ===

  test "incident is recorded in NPC employment history" do
    initial_count = @hired_recruit.employment_history.length

    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 3,
      description: "Reactor coolant leak",
      is_pip_infestation: false
    )

    @hired_recruit.reload
    assert_equal initial_count + 1, @hired_recruit.employment_history.length

    last_entry = @hired_recruit.employment_history.last
    assert_equal 3, last_entry["severity"]
    assert_includes last_entry["description"], "Reactor coolant leak"
  end

  test "high chaos NPCs accumulate more incidents over time" do
    # This is a statistical test - run multiple simulations
    high_chaos_recruit = Recruit.create!(
      race: "krog",
      npc_class: "engineer",
      skill: 85,
      chaos_factor: 90,
      level_tier: 1,
      available_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    high_chaos_hired = HiredRecruit.create_from_recruit!(high_chaos_recruit, @user)

    low_chaos_recruit = Recruit.create!(
      race: "solari",
      npc_class: "engineer",
      skill: 85,
      chaos_factor: 10,
      level_tier: 1,
      available_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    low_chaos_hired = HiredRecruit.create_from_recruit!(low_chaos_recruit, @user)

    # Run 1000 simulated breakdown checks
    high_chaos_incidents = 0
    low_chaos_incidents = 0

    1000.times do
      high_chaos_incidents += 1 if IncidentService.should_incident?(chaos_factor: high_chaos_hired.chaos_factor)
      low_chaos_incidents += 1 if IncidentService.should_incident?(chaos_factor: low_chaos_hired.chaos_factor)
    end

    # High chaos should have significantly more incidents
    # With 90 vs 10 chaos factor, expect roughly 3-9x difference
    assert high_chaos_incidents > low_chaos_incidents * 2,
      "High chaos NPC (#{high_chaos_incidents}) should have significantly more incidents than low chaos (#{low_chaos_incidents})"
  end

  # === Polymorphic Association ===

  test "incident can be associated with a ship" do
    incident = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Ship incident"
    )

    assert_equal @ship, incident.asset
    assert_equal "Ship", incident.asset_type
  end

  test "incident can be associated with a building" do
    incident = Incident.create!(
      asset: @building,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Building incident"
    )

    assert_equal @building, incident.asset
    assert_equal "Building", incident.asset_type
  end

  # === Validation ===

  test "incident requires valid severity 1-5" do
    incident = Incident.new(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 6,
      description: "Invalid severity"
    )

    refute incident.valid?
    assert_includes incident.errors[:severity], "is not included in the list"
  end

  test "incident requires description" do
    incident = Incident.new(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2
    )

    refute incident.valid?
    assert_includes incident.errors[:description], "can't be blank"
  end

  # === Resolution ===

  test "resolved scope excludes unresolved incidents" do
    unresolved = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Unresolved"
    )

    resolved = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Resolved",
      resolved_at: Time.current
    )

    assert_includes Incident.resolved, resolved
    refute_includes Incident.resolved, unresolved
  end

  test "unresolved scope includes active incidents" do
    unresolved = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Unresolved"
    )

    resolved = Incident.create!(
      asset: @ship,
      hired_recruit: @hired_recruit,
      severity: 2,
      description: "Resolved",
      resolved_at: Time.current
    )

    assert_includes Incident.unresolved, unresolved
    refute_includes Incident.unresolved, resolved
  end

  # === Resolution with Assistant ===

  test "resolve_with_assistant! resolves incident and sets cooldown" do
    hiring = Hiring.create!(
      user: @user, hired_recruit: @hired_recruit, assignable: @ship,
      status: "active", wage: 100, hired_at: Time.current
    )
    @hired_recruit.update!(role: "assistant", assistant_cooldown_until: nil)

    incident = Incident.create!(asset: @ship, severity: 2, description: "Broken sensor")
    incident.resolve_with_assistant!(@hired_recruit)

    assert incident.resolved?
    assert @hired_recruit.reload.on_cooldown?
    assert_in_delta HiredRecruit::ASSISTANT_COOLDOWN.from_now, @hired_recruit.assistant_cooldown_until, 2.seconds

    # Inbox message created for asset owner
    msg = @user.messages.last
    assert_equal "incident", msg.category
    assert_match(/resolved/i, msg.body)
  end

  test "resolve_with_assistant! raises if assistant on cooldown" do
    @hired_recruit.update!(role: "assistant", assistant_cooldown_until: 2.hours.from_now)

    incident = Incident.create!(asset: @ship, severity: 2, description: "Broken sensor")

    assert_raises(StandardError) do
      incident.resolve_with_assistant!(@hired_recruit)
    end
    refute incident.resolved?
  end

  # === Resolution with Nearby NPC ===

  test "resolve_with_nearby_npc! succeeds with seeded random below threshold" do
    hiring = Hiring.create!(
      user: @user, hired_recruit: @hired_recruit, assignable: @ship,
      status: "active", wage: 100, hired_at: Time.current
    )

    incident = Incident.create!(asset: @ship, severity: 2, description: "Engine failure")

    # Seed random to produce success (value >= 0.40)
    rng = Random.new(42) # Random.new(42).rand => 0.374... need to find a success seed
    # We'll pass rng explicitly; find seed that gives >= 0.40
    # Let's just test both paths by mocking
    incident.resolve_with_nearby_npc!(@hired_recruit, random: Random.new(1))
    # Random.new(1).rand => 0.417... >= 0.40 = success

    assert incident.resolved?
    msg = @user.messages.last
    assert_equal "incident", msg.category
  end

  test "resolve_with_nearby_npc! fails with seeded random below threshold creates new incident" do
    hiring = Hiring.create!(
      user: @user, hired_recruit: @hired_recruit, assignable: @ship,
      status: "active", wage: 100, hired_at: Time.current
    )

    incident = Incident.create!(asset: @ship, severity: 2, description: "Engine failure")
    initial_count = Incident.count

    # Random.new(0).rand => 0.548... >= 0.40 = success, need failure (<0.40)
    # Random.new(42).rand => 0.374... < 0.40 = failure!
    incident.resolve_with_nearby_npc!(@hired_recruit, random: Random.new(42))

    refute incident.resolved?, "Original incident should stay unresolved on failure"
    assert_equal initial_count + 1, Incident.count, "New incident should be created"

    new_incident = Incident.last
    assert_equal @ship, new_incident.asset
    assert_equal [incident.severity + 1, 5].min, new_incident.severity
  end

  test "resolve_with_nearby_npc! caps new incident severity at 5" do
    hiring = Hiring.create!(
      user: @user, hired_recruit: @hired_recruit, assignable: @ship,
      status: "active", wage: 100, hired_at: Time.current
    )

    incident = Incident.create!(asset: @ship, severity: 5, description: "Catastrophe")
    incident.resolve_with_nearby_npc!(@hired_recruit, random: Random.new(42))

    new_incident = Incident.last
    assert_equal 5, new_incident.severity
  end

  # === can_use_nearby_npc? ===

  test "can_use_nearby_npc? true when NPC is on same asset" do
    hiring = Hiring.create!(
      user: @user, hired_recruit: @hired_recruit, assignable: @ship,
      status: "active", wage: 100, hired_at: Time.current
    )

    incident = Incident.create!(asset: @ship, severity: 2, description: "Test")
    assert incident.can_use_nearby_npc?(@hired_recruit)
  end

  test "can_use_nearby_npc? false when NPC is on different asset" do
    hiring = Hiring.create!(
      user: @user, hired_recruit: @hired_recruit, assignable: @building,
      status: "active", wage: 100, hired_at: Time.current
    )

    incident = Incident.create!(asset: @ship, severity: 2, description: "Test")
    refute incident.can_use_nearby_npc?(@hired_recruit)
  end

  test "can_use_nearby_npc? false when NPC has no hiring on that asset" do
    # NPC has no hirings at all
    incident = Incident.create!(asset: @ship, severity: 2, description: "Test")
    refute incident.can_use_nearby_npc?(@hired_recruit)
  end
end
