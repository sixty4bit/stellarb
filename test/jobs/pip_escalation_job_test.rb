# frozen_string_literal: true

require "test_helper"

class PipEscalationJobTest < ActiveJob::TestCase
  self.use_transactional_tests = true

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
      function: "refining",
      tier: 2
    )
  end

  # === Severity Escalation ===

  test "unresolved pip infestation severity does not increase beyond 5" do
    incident = Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 2.days.ago
    )

    PipEscalationJob.new.perform

    incident.reload
    assert_equal 5, incident.severity, "Severity should not exceed 5"
  end

  test "non-pip incidents are not affected by escalation" do
    incident = Incident.create!(
      asset: @ship,
      severity: 2,
      description: "Regular incident",
      is_pip_infestation: false,
      created_at: 2.days.ago
    )

    PipEscalationJob.new.perform

    incident.reload
    assert_equal 2, incident.severity, "Non-pip incident severity should not change"
  end

  test "resolved pip infestations are not escalated" do
    incident = Incident.create!(
      asset: @ship,
      severity: 3,
      description: "Resolved pip infestation",
      is_pip_infestation: true,
      resolved_at: 1.day.ago,
      created_at: 2.days.ago
    )

    PipEscalationJob.new.perform

    incident.reload
    assert_equal 3, incident.severity, "Resolved pip incident should not escalate"
  end

  # === Spreading ===

  test "pip infestation spreads to adjacent ship in same system" do
    # Create pip infestation on ship
    Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Original pip infestation",
      is_pip_infestation: true,
      created_at: 2.days.ago
    )

    # Create another ship in same system
    other_ship = Ship.create!(
      name: "Enterprise",
      user: @user,
      race: "vex",
      hull_size: "frigate",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @system
    )

    # Force spreading (normally random)
    original_method = PipEscalationJob.method(:should_spread?)
    PipEscalationJob.define_singleton_method(:should_spread?) { true }

    begin
      PipEscalationJob.new.perform

      other_ship_incidents = Incident.pip_infestations.where(asset: other_ship)
      assert_equal 1, other_ship_incidents.count, "Pip should have spread to adjacent ship"
    ensure
      PipEscalationJob.define_singleton_method(:should_spread?, original_method)
    end
  end

  test "pip infestation spreads to adjacent building in same system" do
    # Create pip infestation on ship
    Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Original pip infestation",
      is_pip_infestation: true,
      created_at: 2.days.ago
    )

    # Force spreading
    original_method = PipEscalationJob.method(:should_spread?)
    PipEscalationJob.define_singleton_method(:should_spread?) { true }

    begin
      PipEscalationJob.new.perform

      building_incidents = Incident.pip_infestations.where(asset: @building)
      assert_equal 1, building_incidents.count, "Pip should have spread to adjacent building"
    ensure
      PipEscalationJob.define_singleton_method(:should_spread?, original_method)
    end
  end

  test "pip does not spread to assets in different system" do
    other_system = System.create!(
      name: "Other System",
      x: 6, y: 6, z: 6,  # Valid coordinates (divisible by 3)
      discovered_by: @user
    )

    other_ship = Ship.create!(
      name: "Distant Ship",
      user: @user,
      race: "vex",
      hull_size: "frigate",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: other_system
    )

    # Create pip infestation on original ship
    Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Original pip infestation",
      is_pip_infestation: true,
      created_at: 2.days.ago
    )

    # Force spreading
    original_method = PipEscalationJob.method(:should_spread?)
    PipEscalationJob.define_singleton_method(:should_spread?) { true }

    begin
      PipEscalationJob.new.perform

      other_ship_incidents = Incident.pip_infestations.where(asset: other_ship)
      assert_equal 0, other_ship_incidents.count, "Pip should NOT spread to distant system"
    ensure
      PipEscalationJob.define_singleton_method(:should_spread?, original_method)
    end
  end

  test "pip does not spread to already infested assets" do
    other_ship = Ship.create!(
      name: "Already Infested",
      user: @user,
      race: "vex",
      hull_size: "frigate",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @system
    )

    # Create pip infestations on both ships
    Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Original pip infestation",
      is_pip_infestation: true,
      created_at: 2.days.ago
    )

    existing_incident = Incident.create!(
      asset: other_ship,
      severity: 5,
      description: "Already infested",
      is_pip_infestation: true,
      created_at: 1.day.ago
    )

    # Force spreading
    original_method = PipEscalationJob.method(:should_spread?)
    PipEscalationJob.define_singleton_method(:should_spread?) { true }

    begin
      PipEscalationJob.new.perform

      # Should still only have 1 incident on other_ship
      other_ship_incidents = Incident.pip_infestations.where(asset: other_ship)
      assert_equal 1, other_ship_incidents.count, "Pip should NOT create duplicate on already infested asset"
    ensure
      PipEscalationJob.define_singleton_method(:should_spread?, original_method)
    end
  end

  # === Return Value ===

  test "returns summary hash with counts" do
    Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Pip infestation",
      is_pip_infestation: true,
      created_at: 2.days.ago
    )

    result = PipEscalationJob.new.perform

    assert_kind_of Hash, result
    assert result.key?(:incidents_processed)
    assert result.key?(:spread_count)
  end

  # === Spread Rate ===

  test "spread chance is approximately 10% per adjacent asset" do
    spread_count = 0
    10000.times do
      spread_count += 1 if PipEscalationJob.should_spread?
    end

    # With 10% chance, expect ~1000 hits out of 10000
    # Allow for variance: 700-1300 is reasonable
    assert_in_delta 1000, spread_count, 300,
      "Spread rate should be approximately 10% (got #{spread_count}/10000 = #{spread_count / 100.0}%)"
  end
end
