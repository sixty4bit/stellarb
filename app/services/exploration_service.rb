# frozen_string_literal: true

# ExplorationService helps players find unexplored systems
# Finds the closest coordinates that haven't been visited yet
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

  def initialize(user, ship)
    @user = user
    @ship = ship
    @current_system = ship.current_system
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

  # ============================================
  # Orbital Exploration
  # ============================================

  # Find the closest unexplored coordinate following orbital pattern
  # - First searches at the same orbital distance as current position from origin
  # - Then expands outward to the next distance ring
  #
  # @return [Hash, nil] {x:, y:, z:} or nil if all explored
  def closest_unexplored_orbital
    current_pos = current_position
    current_distance = distance_from_origin(current_pos[:x], current_pos[:y], current_pos[:z]).round

    # Search from current distance outward (within valid coordinate range)
    max_distance = Math.sqrt(3 * (VALID_COORDS.max ** 2)).ceil
    
    (current_distance..max_distance).each do |ring_distance|
      target = find_unexplored_at_orbital_distance(ring_distance, current_pos)
      return target if target
    end

    # Also search inward if nothing found outward
    (0...current_distance).reverse_each do |ring_distance|
      target = find_unexplored_at_orbital_distance(ring_distance, current_pos)
      return target if target
    end

    nil
  end

  # Get current position from ship system or default to origin
  # @return [Hash] { x:, y:, z: }
  def current_position
    if @current_system
      { x: @current_system.x, y: @current_system.y, z: @current_system.z }
    else
      { x: 0, y: 0, z: 0 }
    end
  end

  private

  # Calculate distance from origin (0,0,0)
  def distance_from_origin(x, y, z)
    Math.sqrt(x**2 + y**2 + z**2)
  end

  # Find an unexplored coordinate at a specific distance from origin
  # @param distance [Integer] The orbital ring distance
  # @param current_pos [Hash] Current position for proximity sorting
  # @return [Hash, nil] {x:, y:, z:} or nil
  def find_unexplored_at_orbital_distance(distance, current_pos)
    explored = explored_coordinates_set
    tolerance = 0.5
    candidates = []

    VALID_COORDS.each do |x|
      VALID_COORDS.each do |y|
        VALID_COORDS.each do |z|
          d = distance_from_origin(x, y, z)
          if (d - distance).abs <= tolerance && !explored.include?([x, y, z])
            candidates << { x: x, y: y, z: z }
          end
        end
      end
    end

    # Sort by distance from current position (closest first)
    candidates.min_by do |c|
      dx = c[:x] - current_pos[:x]
      dy = c[:y] - current_pos[:y]
      dz = c[:z] - current_pos[:z]
      dx**2 + dy**2 + dz**2
    end
  end

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
end
