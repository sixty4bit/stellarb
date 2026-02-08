# frozen_string_literal: true

# ExplorationService helps players find unexplored systems
# Finds the closest coordinates that haven't been visited yet
class ExplorationService
  # Coordinate range
  COORD_MIN = -9
  COORD_MAX = 9
  VALID_COORDS = (COORD_MIN..COORD_MAX).to_a.freeze

  # Direction mappings for filtering candidates
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

  # Find the closest unexplored coordinate by expanding outward from current position
  # @param direction [Symbol, nil] Optional direction filter
  # @return [Hash, nil] {x:, y:, z:, distance:} or nil
  def closest_unexplored(direction: nil)
    explored = explored_coordinates_set
    cx, cy, cz = current_coords

    # Expand in shells of increasing distance
    max_range = COORD_MAX - COORD_MIN
    (1..max_range).each do |radius|
      best = nil
      best_dist = Float::INFINITY

      each_coord_at_radius(cx, cy, cz, radius) do |x, y, z|
        next if explored.include?([x, y, z])
        next if direction && !matches_direction?(x, y, z, direction)

        dist = Math.sqrt((x - cx)**2 + (y - cy)**2 + (z - cz)**2)
        if dist < best_dist
          best = { x: x, y: y, z: z, distance: dist }
          best_dist = dist
        end
      end

      return best if best
    end

    nil
  end

  # Get unexplored coordinates sorted by distance
  # @param direction [Symbol, nil] Optional direction filter
  # @param limit [Integer, nil] Maximum results
  # @return [Array<Hash>]
  def all_unexplored(direction: nil, limit: nil)
    explored = explored_coordinates_set
    cx, cy, cz = current_coords
    candidates = []

    each_valid_coord do |x, y, z|
      next if explored.include?([x, y, z])
      next if direction && !matches_direction?(x, y, z, direction)

      distance = Math.sqrt((x - cx)**2 + (y - cy)**2 + (z - cz)**2)
      candidates << { x: x, y: y, z: z, distance: distance }
    end

    sorted = candidates.sort_by { |c| c[:distance] }
    limit ? sorted.first(limit) : sorted
  end

  def all_explored?
    explored_count >= total_coordinates
  end

  def explored_count
    explored_coordinates_set.size
  end

  def total_coordinates
    (COORD_MAX - COORD_MIN + 1) ** 3
  end

  def progress_percentage
    return 100.0 if total_coordinates.zero?
    (explored_count.to_f / total_coordinates * 100).round(2)
  end

  # Find closest unexplored in orbital pattern (same distance from origin, then expand)
  def closest_unexplored_orbital
    current_pos = current_position
    current_distance = Math.sqrt(current_pos[:x]**2 + current_pos[:y]**2 + current_pos[:z]**2).round
    explored = explored_coordinates_set

    max_distance = Math.sqrt(3 * (COORD_MAX**2)).ceil

    # Search outward from current orbital distance
    (current_distance..max_distance).each do |ring|
      target = find_unexplored_at_orbital_distance(ring, current_pos, explored)
      return target if target
    end

    # Search inward
    (0...current_distance).reverse_each do |ring|
      target = find_unexplored_at_orbital_distance(ring, current_pos, explored)
      return target if target
    end

    nil
  end

  def current_position
    if @current_system
      { x: @current_system.x, y: @current_system.y, z: @current_system.z }
    else
      { x: 0, y: 0, z: 0 }
    end
  end

  private

  def current_coords
    if @current_system
      [@current_system.x, @current_system.y, @current_system.z]
    else
      [0, 0, 0]
    end
  end

  # Iterate coordinates within a Chebyshev distance (cube shell) from center
  def each_coord_at_radius(cx, cy, cz, radius)
    ((cx - radius)..(cx + radius)).each do |x|
      next if x < COORD_MIN || x > COORD_MAX
      ((cy - radius)..(cy + radius)).each do |y|
        next if y < COORD_MIN || y > COORD_MAX
        ((cz - radius)..(cz + radius)).each do |z|
          next if z < COORD_MIN || z > COORD_MAX
          # Only yield coordinates on the shell (at least one axis at max distance)
          next unless (x - cx).abs == radius || (y - cy).abs == radius || (z - cz).abs == radius
          yield x, y, z
        end
      end
    end
  end

  # Iterate all valid coordinates
  def each_valid_coord
    (COORD_MIN..COORD_MAX).each do |x|
      (COORD_MIN..COORD_MAX).each do |y|
        (COORD_MIN..COORD_MAX).each do |z|
          yield x, y, z
        end
      end
    end
  end

  def find_unexplored_at_orbital_distance(distance, current_pos, explored)
    tolerance = 0.5
    best = nil
    best_dist_sq = Float::INFINITY

    # Only check coords within the distance range (optimization)
    range_min = [COORD_MIN, -(distance + 1).ceil].max
    range_max = [COORD_MAX, (distance + 1).ceil].min

    (range_min..range_max).each do |x|
      (range_min..range_max).each do |y|
        (range_min..range_max).each do |z|
          d = Math.sqrt(x**2 + y**2 + z**2)
          next unless (d - distance).abs <= tolerance
          next if explored.include?([x, y, z])

          dist_sq = (x - current_pos[:x])**2 + (y - current_pos[:y])**2 + (z - current_pos[:z])**2
          if dist_sq < best_dist_sq
            best = { x: x, y: y, z: z }
            best_dist_sq = dist_sq
          end
        end
      end
    end

    best
  end

  def explored_coordinates_set
    @explored_coordinates_set ||= begin
      explored = Set.new

      @user.system_visits.includes(:system).map(&:system).each do |system|
        coords = [system.x, system.y, system.z]
        next unless coords.all? { |c| c >= COORD_MIN && c <= COORD_MAX }
        explored.add(coords)
      end

      @user.explored_coordinates.pluck(:x, :y, :z).each do |x, y, z|
        explored.add([x, y, z])
      end

      explored
    end
  end

  def matches_direction?(x, y, z, direction)
    return true unless @current_system

    dir_config = DIRECTIONS[direction.to_sym]
    return true unless dir_config

    case dir_config[:axis]
    when :x
      return false unless y == @current_system.y && z == @current_system.z
      dir_config[:positive] ? x > @current_system.x : x < @current_system.x
    when :y
      return false unless x == @current_system.x && z == @current_system.z
      dir_config[:positive] ? y > @current_system.y : y < @current_system.y
    when :z
      return false unless x == @current_system.x && y == @current_system.y
      dir_config[:positive] ? z > @current_system.z : z < @current_system.z
    else
      true
    end
  end

  public

  # Realize a system at ship's current coordinates and handle arrival.
  # Called after ship arrives at explored coordinates.
  # @param ship [Ship] the arrived ship
  def realize_and_arrive!(ship)
    x = ship.location_x
    y = ship.location_y
    z = ship.location_z

    # Try to find or discover a system at these coordinates
    existing_system = System.find_by(x: x, y: y, z: z)

    if existing_system
      # Dock at existing system
      ship.update!(current_system_id: existing_system.id, status: "docked")
      SystemVisit.record_visit(@user, existing_system)
      ExploredCoordinate.mark_explored!(user: @user, x: x, y: y, z: z, has_system: true)
    else
      # Try procedural generation
      begin
        discovered = System.discover_at(x: x, y: y, z: z, user: @user)
        ship.update!(current_system_id: discovered.id, status: "docked")
        SystemVisit.record_visit(@user, discovered)
        ExploredCoordinate.mark_explored!(user: @user, x: x, y: y, z: z, has_system: true)
      rescue => e
        # No system here (proc gen might reject coords) — mark as empty
        ExploredCoordinate.mark_explored!(user: @user, x: x, y: y, z: z, has_system: false)
      end
    end
  end
end
