# frozen_string_literal: true

# ExplorationService helps players find unexplored systems
# Supports multiple exploration strategies: directional, growing arcs, and orbital
class ExplorationService
  # Valid coordinate values (0-9, divisible by 3)
  VALID_COORDS = [0, 3, 6, 9].freeze

  # Direction mappings for filtering candidates
  # Each direction is defined by which axis changes and in which direction
  DIRECTIONS = {
    spinward: { axis: :x, positive: true },
    antispinward: { axis: :x, positive: false },
    north: { axis: :y, positive: true },
    south: { axis: :y, positive: false },
    up: { axis: :z, positive: true },
    down: { axis: :z, positive: false }
  }.freeze

  MAX_SEARCH_DISTANCE = 10 # Maximum orbital rings to search
  MAX_SHELL_DISTANCE = 50  # Maximum distance for full shell generation (optimization)

  def initialize(user, ship = nil)
    @user = user
    @ship = ship
    @current_system = ship&.current_system
  end

  # Find the closest unexplored coordinates
  # @param direction [Symbol, nil] Optional direction filter (:spinward, :antispinward, :north, :south, :up, :down)
  # @return [Hash, nil] The closest unexplored coordinate {x:, y:, z:, distance:} or nil if all explored
  def closest_unexplored(direction: nil)
    explored = explored_coordinates_set
    candidates = []

    VALID_COORDS.each do |x|
      VALID_COORDS.each do |y|
        VALID_COORDS.each do |z|
          next if explored.include?([x, y, z])
          next if direction && !matches_direction?(x, y, z, direction)

          distance = calculate_distance(x, y, z)
          candidates << { x: x, y: y, z: z, distance: distance }
        end
      end
    end

    candidates.min_by { |c| c[:distance] }
  end

  # Get all unexplored coordinates sorted by distance
  # @param direction [Symbol, nil] Optional direction filter
  # @param limit [Integer, nil] Maximum number of results
  # @return [Array<Hash>] List of unexplored coordinates with distances
  def all_unexplored(direction: nil, limit: nil)
    explored = explored_coordinates_set
    candidates = []

    VALID_COORDS.each do |x|
      VALID_COORDS.each do |y|
        VALID_COORDS.each do |z|
          next if explored.include?([x, y, z])
          next if direction && !matches_direction?(x, y, z, direction)

          distance = calculate_distance(x, y, z)
          candidates << { x: x, y: y, z: z, distance: distance }
        end
      end
    end

    sorted = candidates.sort_by { |c| c[:distance] }
    limit ? sorted.first(limit) : sorted
  end

  # Find the closest unexplored coordinate following orbital pattern
  # - First searches at the same orbital distance as current position
  # - Then expands outward to the next distance ring
  #
  # @return [Hash, nil] {x:, y:, z:} or nil if all explored
  def closest_unexplored_orbital
    current_pos = current_position
    current_distance = distance_from_origin(current_pos[:x], current_pos[:y], current_pos[:z]).round

    # Search from current distance outward
    (current_distance..current_distance + MAX_SEARCH_DISTANCE).each do |ring_distance|
      target = find_unexplored_at_distance(ring_distance, current_pos)
      return target if target
    end

    # Also search inward if nothing found outward
    (0...current_distance).reverse_each do |ring_distance|
      target = find_unexplored_at_distance(ring_distance, current_pos)
      return target if target
    end

    nil
  end

  # Check if all valid coordinates have been explored
  # @return [Boolean]
  def all_explored?
    explored_count >= total_coordinates
  end

  # Count of explored coordinates
  # @return [Integer]
  def explored_count
    explored_coordinates_set.size
  end

  # Total possible coordinates
  # @return [Integer]
  def total_coordinates
    VALID_COORDS.size ** 3  # 4^3 = 64
  end

  # Exploration progress as percentage
  # @return [Float]
  def progress_percentage
    return 100.0 if total_coordinates.zero?

    (explored_count.to_f / total_coordinates * 100).round(2)
  end

  private

  # Build a set of explored coordinates for efficient lookup
  # Combines system visits AND explicitly marked explored coordinates
  # @return [Set<Array<Integer>>]
  def explored_coordinates_set
    @explored_coordinates_set ||= begin
      explored = Set.new

      # Add coordinates from system visits
      visited_systems = @user.system_visits.includes(:system).map(&:system)
      visited_systems.each do |system|
        coords = [system.x, system.y, system.z]
        if coords.all? { |c| VALID_COORDS.include?(c) }
          explored.add(coords)
        end
      end

      # Add coordinates from ExploredCoordinate records
      @user.explored_coordinates.pluck(:x, :y, :z).each do |x, y, z|
        explored.add([x, y, z])
      end

      explored
    end
  end

  # Calculate 3D Euclidean distance from current position
  # @return [Float]
  def calculate_distance(x, y, z)
    return Float::INFINITY unless @current_system

    cx = @current_system.x
    cy = @current_system.y
    cz = @current_system.z

    Math.sqrt((x - cx)**2 + (y - cy)**2 + (z - cz)**2)
  end

  # Check if coordinates match the specified direction from current position
  # @param x [Integer] Target X coordinate
  # @param y [Integer] Target Y coordinate
  # @param z [Integer] Target Z coordinate
  # @param direction [Symbol] Direction to check
  # @return [Boolean]
  def matches_direction?(x, y, z, direction)
    return true unless @current_system

    dir_config = DIRECTIONS[direction.to_sym]
    return true unless dir_config  # Unknown direction, don't filter

    case dir_config[:axis]
    when :x
      dir_config[:positive] ? x > @current_system.x : x < @current_system.x
    when :y
      dir_config[:positive] ? y > @current_system.y : y < @current_system.y
    when :z
      dir_config[:positive] ? z > @current_system.z : z < @current_system.z
    else
      true
    end
  end

  # Get current position from ship or default to origin
  def current_position
    if @ship&.current_system
      system = @ship.current_system
      { x: system.x, y: system.y, z: system.z }
    elsif @ship&.location_x
      { x: @ship.location_x, y: @ship.location_y, z: @ship.location_z }
    else
      { x: 0, y: 0, z: 0 }
    end
  end

  def distance_from_origin(x, y, z)
    Math.sqrt(x**2 + y**2 + z**2)
  end

  # Find an unexplored coordinate at a specific distance from origin
  # For large distances, uses sampling instead of full enumeration
  #
  # @param distance [Integer] The orbital ring distance
  # @param current_pos [Hash] Current position for proximity sorting
  # @return [Hash, nil] {x:, y:, z:} or nil
  def find_unexplored_at_distance(distance, current_pos)
    candidates = generate_shell_coordinates(distance, current_pos)
    explored_set = explored_coordinates_set

    candidates.find do |coord|
      !explored_set.include?([coord[:x], coord[:y], coord[:z]])
    end
  end

  # Generate coordinates on a spherical shell at given distance
  # Uses full enumeration for small distances, sampling for large ones
  #
  # @param distance [Integer] The target distance
  # @param center [Hash] Center position for proximity sorting
  # @return [Array<Hash>] Array of {x:, y:, z:} candidates
  def generate_shell_coordinates(distance, center = { x: 0, y: 0, z: 0 })
    return [{ x: 0, y: 0, z: 0 }] if distance == 0

    if distance <= MAX_SHELL_DISTANCE
      generate_full_shell(distance, center)
    else
      generate_sampled_shell(distance, center)
    end
  end

  # Full enumeration for small distances
  def generate_full_shell(distance, center)
    candidates = []
    tolerance = 0.5

    (-distance..distance).each do |x|
      (-distance..distance).each do |y|
        (-distance..distance).each do |z|
          d = distance_from_origin(x, y, z)
          if (d - distance).abs <= tolerance
            candidates << { x: x, y: y, z: z }
          end
        end
      end
    end

    sort_by_proximity(candidates, center)
  end

  # Sampled points for large distances (using spherical coordinate sampling)
  def generate_sampled_shell(distance, center)
    candidates = []

    # Generate points using spherical coordinates
    # Increase sample density for larger spheres to maintain coverage
    num_samples = [100, distance].max

    num_samples.times do |i|
      # Use golden spiral for even distribution
      phi = Math.acos(1 - 2.0 * (i + 0.5) / num_samples)
      theta = Math::PI * (1 + Math.sqrt(5)) * i

      x = (distance * Math.sin(phi) * Math.cos(theta)).round
      y = (distance * Math.sin(phi) * Math.sin(theta)).round
      z = (distance * Math.cos(phi)).round

      candidates << { x: x, y: y, z: z }
    end

    # Also add axis-aligned points for predictability
    [
      { x: distance, y: 0, z: 0 },
      { x: -distance, y: 0, z: 0 },
      { x: 0, y: distance, z: 0 },
      { x: 0, y: -distance, z: 0 },
      { x: 0, y: 0, z: distance },
      { x: 0, y: 0, z: -distance }
    ].each { |c| candidates << c }

    candidates.uniq { |c| [c[:x], c[:y], c[:z]] }
    sort_by_proximity(candidates, center)
  end

  def sort_by_proximity(candidates, center)
    candidates.sort_by do |c|
      dx = c[:x] - center[:x]
      dy = c[:y] - center[:y]
      dz = c[:z] - center[:z]
      dx**2 + dy**2 + dz**2
    end
  end
end
