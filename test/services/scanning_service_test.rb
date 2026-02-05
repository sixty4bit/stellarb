# frozen_string_literal: true

require "test_helper"

class ScanningServiceTest < ActiveSupport::TestCase
  # Scanning is the Phase 2 mechanic for discovering reserved systems
  # Players learn to triangulate signatures and find the Talos Arm

  setup do
    @user = User.create!(
      email: "scanner@example.com",
      name: "Scanner Test",
      tutorial_phase: :proving_ground
    )
    # Start at The Cradle
    @cradle = System.discover_at(x: 0, y: 0, z: 0, user: @user)
    @ship = Ship.create!(
      user: @user,
      name: "Scanner Ship",
      hull_size: "scout",
      race: "solari",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @cradle
    )
  end

  # Basic scanning functionality
  test "scan returns list of nearby signatures within range" do
    result = ScanningService.scan(ship: @ship)

    assert result.is_a?(Hash)
    assert result.key?(:signatures)
    assert result[:signatures].is_a?(Array)
  end

  test "scan from Cradle detects Talos Arm systems" do
    result = ScanningService.scan(ship: @ship)

    assert result[:signatures].length >= 1
    # Should detect at least Talos Prime which is 1 unit away
    distances = result[:signatures].map { |s| s[:distance] }
    assert distances.any? { |d| d <= 2 }, "Should detect signatures within 2 units"
  end

  test "scan returns signature strength based on distance" do
    result = ScanningService.scan(ship: @ship)

    result[:signatures].each do |sig|
      assert sig.key?(:strength), "Should include signal strength"
      assert sig[:strength].between?(0, 100), "Strength should be 0-100"
      # Closer = stronger
      if sig[:distance] < 1.5
        assert sig[:strength] > 50, "Close signatures should be strong"
      end
    end
  end

  test "scan reveals partial coordinates based on signal strength" do
    result = ScanningService.scan(ship: @ship)
    strong_sig = result[:signatures].find { |s| s[:strength] >= 70 }

    skip "No strong signals found in test" unless strong_sig

    # Strong signals reveal more coordinate precision
    assert strong_sig.key?(:estimated_coords)
    coords = strong_sig[:estimated_coords]
    assert coords.key?(:x_range) || coords.key?(:x)
    assert coords.key?(:y_range) || coords.key?(:y)
    assert coords.key?(:z_range) || coords.key?(:z)
  end

  test "scan requires ship to be docked or in system" do
    @ship.update!(status: "in_transit")

    error = assert_raises(ScanningService::ScanError) do
      ScanningService.scan(ship: @ship)
    end
    assert_match(/cannot scan while in transit/i, error.message)
  end

  # Triangulation mechanic
  test "triangulate with 3 scans pinpoints exact coordinates" do
    # Scan from 3 different positions to triangulate
    # Target: Talos IV at (1,1,0) - this is detectable from all 3 positions
    scan1 = ScanningService.scan(ship: @ship)

    # Find a signature that will be visible from all scan positions
    # Talos IV (1,1,0) is good because it's within range of (0,0,0), (0,0,1), and (0,1,0)
    target_sig_id = Digest::SHA256.hexdigest("sig|1|1|0")[0, 16]
    sig1 = scan1[:signatures].find { |s| s[:signature_id] == target_sig_id }
    skip "Target signature not found in scan1" unless sig1

    # Move to Talos III (0,0,1) and scan
    talos3 = System.discover_at(x: 0, y: 0, z: 1, user: @user)
    @ship.update!(current_system: talos3, fuel: 100)
    scan2 = ScanningService.scan(ship: @ship)

    # Move to Talos II (0,1,0) and scan
    talos2 = System.discover_at(x: 0, y: 1, z: 0, user: @user)
    @ship.update!(current_system: talos2, fuel: 100)
    scan3 = ScanningService.scan(ship: @ship)

    # Triangulate
    result = ScanningService.triangulate(
      scans: [
        { system: @cradle, signatures: scan1[:signatures] },
        { system: talos3, signatures: scan2[:signatures] },
        { system: talos2, signatures: scan3[:signatures] }
      ],
      target_signature_id: target_sig_id
    )

    assert result[:success], "Should successfully triangulate: #{result[:error]}"
    assert result[:coordinates].present?
    assert result[:coordinates].key?(:x)
    assert result[:coordinates].key?(:y)
    assert result[:coordinates].key?(:z)
  end

  # Ship sensor range based on attributes
  test "ship sensor range affects scan distance" do
    # Solari ships have better sensors
    solari_ship = Ship.create!(
      user: @user,
      name: "Solari Scanner",
      hull_size: "scout",
      race: "solari",
      variant_idx: 2,
      fuel: 100,
      status: "docked",
      current_system: @cradle
    )

    krog_ship = Ship.create!(
      user: @user,
      name: "Krog Scanner",
      hull_size: "scout",
      race: "krog",
      variant_idx: 3,
      fuel: 100,
      status: "docked",
      current_system: @cradle
    )

    solari_result = ScanningService.scan(ship: solari_ship)
    krog_result = ScanningService.scan(ship: krog_ship)

    # Solari should detect more distant signatures
    solari_max = solari_result[:signatures].map { |s| s[:distance] }.max || 0
    krog_max = krog_result[:signatures].map { |s| s[:distance] }.max || 0

    assert solari_max >= krog_max, "Solari sensors should have better range"
  end

  # Scanning consumes fuel
  test "scanning consumes fuel" do
    @ship.update!(fuel: 100)
    initial_fuel = @ship.fuel

    ScanningService.scan(ship: @ship)
    @ship.reload

    assert @ship.fuel < initial_fuel, "Scanning should consume fuel"
  end

  test "scanning fails if insufficient fuel" do
    @ship.update!(fuel: 0)

    error = assert_raises(ScanningService::InsufficientFuelError) do
      ScanningService.scan(ship: @ship)
    end
    assert_match(/insufficient fuel/i, error.message)
  end

  # Tutorial progress
  test "first scan in Proving Ground triggers tutorial milestone" do
    @user.update!(tutorial_phase: :proving_ground)

    result = ScanningService.scan(ship: @ship)

    assert result[:tutorial_milestone], "Should mark tutorial milestone"
    assert_equal :first_scan, result[:tutorial_milestone]
  end
end
