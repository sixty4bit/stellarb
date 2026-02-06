# Service for exploration operations
# Finds unexplored coordinates in expanding arcs from the ship's position
class ExplorationService
  SEARCH_RADIUS = 10 # Maximum distance to search

  def initialize(user, ship)
    @user = user
    @ship = ship
  end

  # Find the closest unexplored coordinate using expanding arcs
  # Searches in progressively larger shells from the ship's position
  # @return [Hash, nil] Coordinate hash {x:, y:, z:} or nil if all explored
  def closest_unexplored
    origin = ship_position
    return nil unless origin

    # Search in expanding shells (arcs) from distance 1 to SEARCH_RADIUS
    (1..SEARCH_RADIUS).each do |distance|
      candidates = coordinates_at_distance(origin, distance)
      unexplored = candidates.reject { |coord| explored?(coord) }

      # Return the first unexplored coordinate at this distance
      return unexplored.first if unexplored.any?
    end

    nil # All coordinates within search radius are explored
  end

  private

  def ship_position
    if @ship&.current_system
      {
        x: @ship.current_system.x,
        y: @ship.current_system.y,
        z: @ship.current_system.z
      }
    elsif @ship&.location_x
      { x: @ship.location_x, y: @ship.location_y, z: @ship.location_z }
    end
  end

  # Generate all integer coordinates at exactly the given Manhattan distance
  # This creates a "shell" or "arc" around the origin
  def coordinates_at_distance(origin, distance)
    coords = []

    # For each possible x offset
    (-distance..distance).each do |dx|
      remaining = distance - dx.abs
      # For each possible y offset given the x
      (-remaining..remaining).each do |dy|
        # z is determined by the remaining distance
        dz = remaining - dy.abs
        coords << { x: origin[:x] + dx, y: origin[:y] + dy, z: origin[:z] + dz } if dz >= 0
        coords << { x: origin[:x] + dx, y: origin[:y] + dy, z: origin[:z] - dz } if dz > 0
      end
    end

    coords.uniq
  end

  def explored?(coord)
    @explored_cache ||= @user.explored_coordinates.pluck(:x, :y, :z).map { |x, y, z| [x, y, z] }.to_set
    @explored_cache.include?([coord[:x], coord[:y], coord[:z]])
  end
end
