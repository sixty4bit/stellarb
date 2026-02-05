# frozen_string_literal: true

# ScanningService handles the exploration mechanic for Phase 2 (Proving Ground)
# Players use scanning to detect and triangulate signatures of nearby systems
class ScanningService
  class ScanError < StandardError; end
  class InsufficientFuelError < ScanError; end

  SCAN_FUEL_COST = 5  # Fuel consumed per scan
  BASE_SENSOR_RANGE = 3  # Base range in coordinate units

  # Racial sensor bonuses (multiplier to base range)
  RACIAL_SENSOR_BONUSES = {
    "solari" => 1.4,   # Best sensors - 40% bonus
    "vex" => 1.0,      # Standard
    "krog" => 0.8,     # Weaker sensors
    "myrmidon" => 1.1  # Slightly above average
  }.freeze

  # Perform a scan from the ship's current position
  # @param ship [Ship] The ship performing the scan
  # @return [Hash] Scan results with signatures
  def self.scan(ship:)
    new(ship: ship).scan
  end

  # Triangulate exact coordinates from multiple scan results
  # @param scans [Array<Hash>] Array of {system:, signatures:} from different positions
  # @param target_signature_id [String] ID of the signature to triangulate
  # @return [Hash] Triangulation result with coordinates
  def self.triangulate(scans:, target_signature_id:)
    new(ship: nil).triangulate(scans: scans, target_signature_id: target_signature_id)
  end

  def initialize(ship:)
    @ship = ship
  end

  def scan
    validate_can_scan!
    consume_fuel!

    signatures = detect_signatures
    result = build_scan_result(signatures)

    # Check for tutorial milestone
    if first_scan_in_proving_ground?
      result[:tutorial_milestone] = :first_scan
    end

    result
  end

  def triangulate(scans:, target_signature_id:)
    return { success: false, error: "Need at least 3 scans" } if scans.length < 3

    # Find matching signatures across all scans
    matching_sigs = scans.map do |scan_data|
      scan_data[:signatures].find { |s| s[:signature_id] == target_signature_id }
    end.compact

    return { success: false, error: "Signature not found in all scans" } if matching_sigs.length < 3

    # Calculate exact position using triangulation
    # Each scan gives us a distance (from signal strength) and a position
    # With 3+ points, we can solve for the target location
    coordinates = triangulate_position(scans, matching_sigs)

    { success: true, coordinates: coordinates }
  end

  private

  def validate_can_scan!
    raise ScanError, "Cannot scan while in transit" if @ship.status == "in_transit"
    raise ScanError, "Ship has no current system" unless @ship.current_system
    raise InsufficientFuelError, "Insufficient fuel for scan (need #{SCAN_FUEL_COST})" if @ship.fuel < SCAN_FUEL_COST
  end

  def consume_fuel!
    @ship.update!(fuel: @ship.fuel - SCAN_FUEL_COST)
  end

  def sensor_range
    base = BASE_SENSOR_RANGE
    racial_bonus = RACIAL_SENSOR_BONUSES[@ship.race] || 1.0
    hull_bonus = hull_sensor_bonus

    (base * racial_bonus * hull_bonus).round(1)
  end

  def hull_sensor_bonus
    case @ship.hull_size
    when "scout" then 1.2    # Scouts have good sensors
    when "frigate" then 1.0
    when "transport" then 0.9
    when "cruiser" then 1.1
    when "titan" then 1.3    # Big ships have powerful arrays
    else 1.0
    end
  end

  def detect_signatures
    current_pos = {
      x: @ship.current_system.x,
      y: @ship.current_system.y,
      z: @ship.current_system.z
    }

    signatures = []

    # Check all reserved systems in Talos Arm
    ProceduralGeneration::ReservedSystem::TALOS_ARM.each do |coords|
      distance = calculate_distance(current_pos, coords)
      next if distance > sensor_range
      next if distance == 0  # Skip current system

      strength = calculate_signal_strength(distance)
      signatures << build_signature(coords, distance, strength)
    end

    # Also check for any other nearby systems (procedurally generated)
    # For now, just scan a small cube around current position
    scan_nearby_procedural_systems(current_pos, signatures)

    signatures.sort_by { |s| s[:distance] }
  end

  def scan_nearby_procedural_systems(current_pos, signatures)
    range = sensor_range.ceil
    (-range..range).each do |dx|
      (-range..range).each do |dy|
        (-range..range).each do |dz|
          next if dx == 0 && dy == 0 && dz == 0

          x = current_pos[:x] + dx
          y = current_pos[:y] + dy
          z = current_pos[:z] + dz

          next unless valid_coordinates?(x, y, z)

          distance = calculate_distance(current_pos, { x: x, y: y, z: z })
          next if distance > sensor_range

          # Skip if already detected (Talos Arm)
          next if ProceduralGeneration::ReservedSystem.reserved?(x, y, z)

          # Add if system would exist there (deterministic)
          system_data = ProceduralGeneration.generate_system(x, y, z)
          next if system_data[:planet_count] == 0  # Empty space

          strength = calculate_signal_strength(distance)
          signatures << build_signature({ x: x, y: y, z: z }, distance, strength)
        end
      end
    end
  end

  def valid_coordinates?(x, y, z)
    x >= 0 && x <= 999_999 &&
      y >= 0 && y <= 999_999 &&
      z >= 0 && z <= 999_999
  end

  def calculate_distance(from, to)
    dx = to[:x] - from[:x]
    dy = to[:y] - from[:y]
    dz = to[:z] - from[:z]
    Math.sqrt(dx**2 + dy**2 + dz**2)
  end

  def calculate_signal_strength(distance)
    # Signal strength decreases with distance squared (inverse square law)
    # At distance 0: 100, at max_range: ~10
    return 100 if distance <= 0.1

    max_range = sensor_range
    base_strength = 100 * (1 - (distance / (max_range * 1.5))**2)
    [[base_strength.round, 100].min, 0].max
  end

  def build_signature(coords, distance, strength)
    signature_id = Digest::SHA256.hexdigest("sig|#{coords[:x]}|#{coords[:y]}|#{coords[:z]}")[0, 16]

    sig = {
      signature_id: signature_id,
      distance: distance.round(2),
      strength: strength,
      estimated_coords: estimate_coordinates(coords, strength)
    }

    # Mark if this is a reserved (tutorial) system
    if ProceduralGeneration::ReservedSystem.reserved?(coords[:x], coords[:y], coords[:z])
      sig[:classification] = :reserved_system
    else
      sig[:classification] = :unknown
    end

    sig
  end

  def estimate_coordinates(actual_coords, strength)
    # Higher strength = more precise coordinates
    # 0-30: Only general direction
    # 31-60: Rough estimate (±2 units)
    # 61-80: Good estimate (±1 unit)
    # 81-100: Exact coordinates

    if strength >= 80
      { x: actual_coords[:x], y: actual_coords[:y], z: actual_coords[:z] }
    elsif strength >= 60
      {
        x_range: [actual_coords[:x] - 1, actual_coords[:x] + 1],
        y_range: [actual_coords[:y] - 1, actual_coords[:y] + 1],
        z_range: [actual_coords[:z] - 1, actual_coords[:z] + 1]
      }
    elsif strength >= 30
      {
        x_range: [actual_coords[:x] - 2, actual_coords[:x] + 2],
        y_range: [actual_coords[:y] - 2, actual_coords[:y] + 2],
        z_range: [actual_coords[:z] - 2, actual_coords[:z] + 2]
      }
    else
      { direction: calculate_direction(actual_coords) }
    end
  end

  def calculate_direction(target_coords)
    current = @ship.current_system
    dx = target_coords[:x] - current.x
    dy = target_coords[:y] - current.y
    dz = target_coords[:z] - current.z

    directions = []
    directions << (dx > 0 ? "spinward" : "anti-spinward") if dx.abs > 0
    directions << (dy > 0 ? "galactic north" : "galactic south") if dy.abs > 0
    directions << (dz > 0 ? "above plane" : "below plane") if dz.abs > 0

    directions.join(", ")
  end

  def build_scan_result(signatures)
    {
      scan_time: Time.current,
      ship_id: @ship.id,
      ship_name: @ship.name,
      from_system: @ship.current_system.name,
      sensor_range: sensor_range,
      fuel_consumed: SCAN_FUEL_COST,
      signatures: signatures
    }
  end

  def first_scan_in_proving_ground?
    return false unless @ship.user.proving_ground?

    # Check if this is user's first scan ever
    # We could track this in a table, but for simplicity check flight records
    # A scan milestone would typically be tracked separately
    true  # For tutorial, always mark first scan as milestone
  end

  def triangulate_position(scans, matching_sigs)
    # Simple triangulation: use the scan positions and signal strengths
    # to estimate the target position
    #
    # For each scan, we know:
    # - The scan position (system coordinates)
    # - The signal strength (which correlates to distance)
    #
    # We can estimate position as weighted average based on signal strength

    total_weight = 0
    weighted_x = 0
    weighted_y = 0
    weighted_z = 0

    scans.zip(matching_sigs).each do |scan_data, sig|
      system = scan_data[:system]
      weight = sig[:strength]

      # Estimate target distance from this scan position
      # Stronger signal = closer target
      estimated_distance = estimate_distance_from_strength(sig[:strength])

      # Get direction from estimated coords (if available)
      if sig[:estimated_coords][:x]
        # We have exact coords from this scan
        weighted_x += sig[:estimated_coords][:x] * weight
        weighted_y += sig[:estimated_coords][:y] * weight
        weighted_z += sig[:estimated_coords][:z] * weight
      else
        # Use range midpoints
        coords = sig[:estimated_coords]
        weighted_x += average_range(coords[:x_range] || [system.x]) * weight
        weighted_y += average_range(coords[:y_range] || [system.y]) * weight
        weighted_z += average_range(coords[:z_range] || [system.z]) * weight
      end

      total_weight += weight
    end

    {
      x: (weighted_x / total_weight).round,
      y: (weighted_y / total_weight).round,
      z: (weighted_z / total_weight).round
    }
  end

  def estimate_distance_from_strength(strength)
    # Inverse of signal strength calculation
    max_range = BASE_SENSOR_RANGE
    ratio = [strength / 100.0, 0.01].max
    max_range * Math.sqrt(1 - ratio)
  end

  def average_range(range)
    return range.first if range.length == 1

    (range.first + range.last) / 2.0
  end
end
