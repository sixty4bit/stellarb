# frozen_string_literal: true

require "components"
require "minerals"

# FactorySpecializations maps the 8 factory specialization types to their
# input minerals (consume) and output components (produce).
#
# Each specialization produces components from a specific category, and
# consumes the minerals that those components require as inputs.
#
# Reference: Source doc Section 3.6
module FactorySpecializations
  # Build consume list by extracting unique minerals from component inputs
  def self.extract_minerals_from_components(components)
    components
      .flat_map { |c| c[:inputs].keys }
      .uniq
      .sort
  end

  # Build produce list from component names
  def self.extract_component_names(components)
    components.map { |c| c[:name] }
  end

  # 8 factory specializations mapped to Components categories
  ALL = {
    "basic" => {
      consume: extract_minerals_from_components(Components::BASIC_PARTS),
      produce: extract_component_names(Components::BASIC_PARTS)
    }.freeze,

    "electronics" => {
      consume: extract_minerals_from_components(Components::ELECTRONICS),
      produce: extract_component_names(Components::ELECTRONICS)
    }.freeze,

    "structural" => {
      consume: extract_minerals_from_components(Components::STRUCTURAL),
      produce: extract_component_names(Components::STRUCTURAL)
    }.freeze,

    "power" => {
      consume: extract_minerals_from_components(Components::POWER),
      produce: extract_component_names(Components::POWER)
    }.freeze,

    "propulsion" => {
      consume: extract_minerals_from_components(Components::PROPULSION),
      produce: extract_component_names(Components::PROPULSION)
    }.freeze,

    "weapons" => {
      consume: extract_minerals_from_components(Components::WEAPONS),
      produce: extract_component_names(Components::WEAPONS)
    }.freeze,

    "defense" => {
      consume: extract_minerals_from_components(Components::DEFENSE),
      produce: extract_component_names(Components::DEFENSE)
    }.freeze,

    "advanced" => {
      consume: extract_minerals_from_components(Components::ADVANCED),
      produce: extract_component_names(Components::ADVANCED)
    }.freeze
  }.freeze

  # Index for fast lookup by name (case-insensitive)
  BY_NAME = ALL.transform_keys(&:downcase).freeze

  # Reverse index: component name -> specialization
  SPECIALIZATION_BY_COMPONENT = ALL.each_with_object({}) do |(spec_name, config), index|
    config[:produce].each do |component_name|
      index[component_name.downcase] = spec_name
    end
  end.freeze

  class << self
    # Find a specialization by name (case-insensitive)
    # @param name [String] Specialization name
    # @return [Hash, nil] Specialization data or nil if not found
    def find(name)
      return nil if name.nil? || name.to_s.empty?

      BY_NAME[name.to_s.downcase]
    end

    # Get all specialization names
    # @return [Array<String>] List of specialization names
    def names
      ALL.keys
    end

    # Get input minerals (consume) for a specialization
    # @param name [String] Specialization name
    # @return [Array<String>] Input mineral names, or empty array if not found
    def consumes(name)
      find(name)&.dig(:consume) || []
    end

    # Get output components (produce) for a specialization
    # @param name [String] Specialization name
    # @return [Array<String>] Output component names, or empty array if not found
    def produces(name)
      find(name)&.dig(:produce) || []
    end

    # Find which specialization produces a given component
    # @param component_name [String] Component name
    # @return [String, nil] Specialization name, or nil if not found
    def specialization_for_component(component_name)
      return nil if component_name.nil? || component_name.to_s.empty?

      SPECIALIZATION_BY_COMPONENT[component_name.to_s.downcase]
    end
  end
end
