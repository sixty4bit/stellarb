# frozen_string_literal: true

# WarpRouteService provides BFS pathfinding through the warp gate network.
class WarpRouteService
  # Find shortest route between two systems via warp gates.
  # @param from_system [System] origin
  # @param to_system [System] destination
  # @return [Hash, nil] { path: [System, ...], hops: Integer, fuel_cost: Decimal } or nil
  def self.find_route(from_system, to_system)
    if from_system.id == to_system.id
      return { path: [from_system], hops: 0, fuel_cost: 0 }
    end

    # Build adjacency list from active warp gates
    adjacency = build_adjacency_list

    # BFS
    queue = [[from_system.id, [from_system.id]]]
    visited = Set.new([from_system.id])

    while (current_id, path = queue.shift)
      neighbors = adjacency[current_id] || []
      neighbors.each do |neighbor_id|
        next if visited.include?(neighbor_id)

        new_path = path + [neighbor_id]
        if neighbor_id == to_system.id
          systems = System.where(id: new_path).index_by(&:id)
          ordered = new_path.map { |id| systems[id] }
          hops = ordered.size - 1
          return {
            path: ordered,
            hops: hops,
            fuel_cost: hops * WarpGate::WARP_FUEL_COST
          }
        end

        visited.add(neighbor_id)
        queue.push([neighbor_id, new_path])
      end
    end

    nil
  end

  def self.build_adjacency_list
    adjacency = Hash.new { |h, k| h[k] = [] }
    WarpGate.active.pluck(:system_a_id, :system_b_id).each do |a_id, b_id|
      adjacency[a_id] << b_id
      adjacency[b_id] << a_id
    end
    adjacency
  end
  private_class_method :build_adjacency_list
end
