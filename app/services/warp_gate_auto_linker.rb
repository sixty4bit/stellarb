# frozen_string_literal: true

# WarpGateAutoLinker classifies systems into 6 directional pyramids
# and finds the nearest gated system in each pyramid for auto-linking.
class WarpGateAutoLinker
  PYRAMIDS = %i[pos_x neg_x pos_y neg_y pos_z neg_z].freeze

  # Classify target into a pyramid relative to source using dominant axis.
  # Tiebreaker priority: X > Y > Z
  # @param source [System] origin system
  # @param target [System] system to classify
  # @return [Symbol] :pos_x, :neg_x, :pos_y, :neg_y, :pos_z, :neg_z
  def self.classify_pyramid(source, target)
    dx = target.x - source.x
    dy = target.y - source.y
    dz = target.z - source.z

    adx = dx.abs
    ady = dy.abs
    adz = dz.abs

    # Tiebreaker: X > Y > Z (>= for X vs Y, >= for X vs Z, >= for Y vs Z)
    if adx >= ady && adx >= adz
      dx >= 0 ? :pos_x : :neg_x
    elsif ady >= adz
      dy >= 0 ? :pos_y : :neg_y
    else
      dz >= 0 ? :pos_z : :neg_z
    end
  end

  # Find the nearest system in a given pyramid from candidates.
  # @param source [System] origin system
  # @param pyramid [Symbol] pyramid direction
  # @param candidates [Array<System>] systems to search
  # @return [System, nil] nearest system in that pyramid
  def self.find_nearest_in_pyramid(source, pyramid, candidates)
    matching = candidates.select { |c| classify_pyramid(source, c) == pyramid }
    matching.min_by { |c| source.distance_to(c) }
  end
end
