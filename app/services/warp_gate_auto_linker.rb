# frozen_string_literal: true

class WarpGateAutoLinker
  PYRAMIDS = %i[pos_x neg_x pos_y neg_y pos_z neg_z].freeze

  def self.classify_pyramid(source, target)
    dx = target.x - source.x
    dy = target.y - source.y
    dz = target.z - source.z

    adx = dx.abs
    ady = dy.abs
    adz = dz.abs

    if adx >= ady && adx >= adz
      dx >= 0 ? :pos_x : :neg_x
    elsif ady >= adz
      dy >= 0 ? :pos_y : :neg_y
    else
      dz >= 0 ? :pos_z : :neg_z
    end
  end

  def self.find_nearest_in_pyramid(source, pyramid, candidates)
    matching = candidates.select { |c| classify_pyramid(source, c) == pyramid }
    matching.min_by { |c| source.distance_to(c) }
  end

  # Auto-link a newly gated system to nearest systems in each of 6 pyramids.
  # Creates bidirectional WarpGate records.
  # @param system [System] the system that just got a warp gate
  def self.link!(system)
    # Find all other systems with active warp gates
    gated_system_ids = WarpGate.active.pluck(:system_a_id, :system_b_id).flatten.uniq - [system.id]
    candidates = System.where(id: gated_system_ids).to_a

    PYRAMIDS.each do |pyramid|
      nearest = find_nearest_in_pyramid(system, pyramid, candidates)
      next unless nearest

      # Create bidirectional gate if not already connected
      unless WarpGate.between(system, nearest)
        WarpGate.create!(system_a: system, system_b: nearest)
      end
    end
  end

  # Re-evaluate existing gates when a new gate is added.
  # For each existing gated system, check if the new system is now closer
  # in the reverse pyramid direction. If so, replace the old link.
  # @param new_system [System] the newly gated system
  def self.relink_neighbors!(new_system)
    gated_system_ids = WarpGate.active.pluck(:system_a_id, :system_b_id).flatten.uniq - [new_system.id]
    existing_systems = System.where(id: gated_system_ids).to_a

    existing_systems.each do |existing|
      pyramid = classify_pyramid(existing, new_system)

      # Find what existing is currently linked to in that pyramid
      current_links = existing_linked_systems(existing)
      current_in_pyramid = current_links.select { |s| classify_pyramid(existing, s) == pyramid }
      current_nearest = current_in_pyramid.min_by { |s| existing.distance_to(s) }

      if current_nearest.nil? || existing.distance_to(new_system) < existing.distance_to(current_nearest)
        # New system is closer — replace old link if it exists
        if current_nearest
          old_gate = WarpGate.between(existing, current_nearest)
          old_gate&.destroy
        end
        unless WarpGate.between(existing, new_system)
          WarpGate.create!(system_a: existing, system_b: new_system)
        end
      end
    end
  end

  def self.existing_linked_systems(system)
    gate_pairs = system.warp_gates.active.pluck(:system_a_id, :system_b_id)
    linked_ids = gate_pairs.flatten.uniq - [system.id]
    System.where(id: linked_ids).to_a
  end
  private_class_method :existing_linked_systems

  # When a gate is removed, neighbors need to re-evaluate their connections.
  # @param system [System] the system losing its warp gate
  def self.unlink!(system)
    # Find all systems currently linked to this one BEFORE removing gates
    linked = existing_linked_systems(system)

    # Remove all gates involving this system
    system.warp_gates.delete_all

    # For each former neighbor, find a new link in that pyramid direction
    # Candidates include other former neighbors + any remaining gated systems
    linked.each do |neighbor|
      pyramid = classify_pyramid(neighbor, system)
      # Candidates: other gated systems + former neighbors of the removed system
      gated_ids = WarpGate.active.pluck(:system_a_id, :system_b_id).flatten.uniq
      other_linked_ids = linked.map(&:id) - [neighbor.id]
      all_candidate_ids = (gated_ids + other_linked_ids).uniq - [neighbor.id, system.id]
      candidates = System.where(id: all_candidate_ids).to_a
      replacement = find_nearest_in_pyramid(neighbor, pyramid, candidates)
      next unless replacement
      next if WarpGate.between(neighbor, replacement)
      WarpGate.create!(system_a: neighbor, system_b: replacement)
    end
  end
end
