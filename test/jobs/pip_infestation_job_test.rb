# frozen_string_literal: true

require "test_helper"

class PipInfestationJobTest < ActiveJob::TestCase
  # Don't use fixtures - we create our own test data
  self.use_transactional_tests = true

  setup do
    # Clean slate - delete in proper order for FK constraints
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
      name: "Defense Platform Alpha",
      user: @user,
      system: @system,
      race: "krog",
      function: "defense",
      tier: 2
    )
  end

  # === Job Configuration ===

  test "job is enqueued to the default queue" do
    assert_equal "default", PipInfestationJob.new.queue_name
  end

  # === The 1% Rule ===

  test "pip infestation triggers at 1% rate on average" do
    # Statistical test - run 10000 simulations
    pip_count = 0
    10000.times do
      pip_count += 1 if PipInfestationJob.should_pip_infest?
    end

    # With 1% chance, expect ~100 hits out of 10000
    # Allow for variance: 50-150 is reasonable
    assert_in_delta 100, pip_count, 50,
      "Pip infestation rate should be approximately 1% (got #{pip_count}/10000 = #{pip_count / 100.0}%)"
  end

  # === Processing Assets ===

  test "processes all operational ships" do
    # Set a fixed seed so we can predict outcome
    srand(12345)

    # Create multiple ships
    5.times do |i|
      Ship.create!(
        name: "Ship #{i}",
        user: @user,
        race: "vex",
        hull_size: "transport",
        variant_idx: 1,
        fuel: 100,
        status: "docked",
        current_system: @system
      )
    end

    result = PipInfestationJob.new.perform

    assert_kind_of Hash, result
    assert result[:assets_processed] >= 6, "Should process at least 6 ships (5 new + 1 setup)"
  end

  test "processes all operational buildings" do
    # Create multiple buildings
    3.times do |i|
      Building.create!(
        name: "Building #{i}",
        user: @user,
        system: @system,
        race: "krog",
        function: "defense",
        tier: 1
      )
    end

    result = PipInfestationJob.new.perform

    assert result[:assets_processed] >= 4, "Should process at least 4 buildings (3 new + 1 setup)"
  end

  test "skips disabled ships" do
    @ship.update!(disabled_at: Time.current)

    result = PipInfestationJob.new.perform

    # The disabled ship should not be processed (should be 1 building only)
    assert_equal 1, result[:assets_processed], "Should only process 1 operational building"
  end

  test "skips disabled buildings" do
    @building.update!(disabled_at: Time.current)

    result = PipInfestationJob.new.perform

    # The disabled building should not be processed (should be 1 ship only)
    assert_equal 1, result[:assets_processed], "Should only process 1 operational ship"
  end

  # === Pip Infestation Creation ===

  test "creates pip infestation incident when trigger fires" do
    # Force the trigger to always fire by stubbing rand
    original_method = PipInfestationJob.method(:should_pip_infest?)
    PipInfestationJob.define_singleton_method(:should_pip_infest?) { true }

    begin
      result = PipInfestationJob.new.perform

      assert result[:incidents_created] >= 1
      incident = Incident.pip_infestations.last
      assert incident.present?
      assert incident.is_pip_infestation?
      assert_equal 5, incident.severity
    ensure
      PipInfestationJob.define_singleton_method(:should_pip_infest?, original_method)
    end
  end

  test "pip infestation disables the asset" do
    original_method = PipInfestationJob.method(:should_pip_infest?)
    PipInfestationJob.define_singleton_method(:should_pip_infest?) { true }

    begin
      PipInfestationJob.new.perform

      @ship.reload
      assert @ship.disabled?, "Ship should be disabled after pip infestation"
    ensure
      PipInfestationJob.define_singleton_method(:should_pip_infest?, original_method)
    end
  end

  test "pip infestation generates humorous description" do
    original_method = PipInfestationJob.method(:should_pip_infest?)
    PipInfestationJob.define_singleton_method(:should_pip_infest?) { true }

    begin
      PipInfestationJob.new.perform

      incident = Incident.pip_infestations.last
      assert incident.description.present?
      assert incident.description.length > 20, "Description should be substantive"
    ensure
      PipInfestationJob.define_singleton_method(:should_pip_infest?, original_method)
    end
  end

  # === Return Value ===

  test "returns summary hash with counts" do
    result = PipInfestationJob.new.perform

    assert_kind_of Hash, result
    assert result.key?(:assets_processed)
    assert result.key?(:incidents_created)
    assert_kind_of Integer, result[:assets_processed]
    assert_kind_of Integer, result[:incidents_created]
  end

  # === Idempotency ===

  test "does not create duplicate pip infestations on same asset" do
    # Create a pip infestation on the ship
    Incident.create!(
      asset: @ship,
      severity: 5,
      description: "Existing pip infestation",
      is_pip_infestation: true
    )

    original_method = PipInfestationJob.method(:should_pip_infest?)
    PipInfestationJob.define_singleton_method(:should_pip_infest?) { true }

    begin
      result = PipInfestationJob.new.perform

      # Ship already has pip infestation, so should skip it
      ship_incidents = Incident.pip_infestations.where(asset: @ship).count
      assert_equal 1, ship_incidents, "Should not create duplicate pip infestation"
    ensure
      PipInfestationJob.define_singleton_method(:should_pip_infest?, original_method)
    end
  end
end
