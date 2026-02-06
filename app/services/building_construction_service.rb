# frozen_string_literal: true

# BuildingConstructionService handles construction of buildings for Phase 2 tutorial
# Players learn to construct their first asset (Mineral Extractor) in the Proving Ground
class BuildingConstructionService
  # Result struct for construction operations
  ConstructionResult = Struct.new(:success?, :error, :building, :tutorial_milestone?, :tutorial_milestone, :colonial_ticket_unlocked?, :ticket, keyword_init: true) do
    def self.success(building:, tutorial_milestone: nil, ticket: nil)
      new(
        success?: true,
        building: building,
        tutorial_milestone?: tutorial_milestone.present?,
        tutorial_milestone: tutorial_milestone,
        colonial_ticket_unlocked?: ticket.present?,
        ticket: ticket
      )
    end

    def self.failure(error)
      new(success?: false, error: error)
    end
  end

  # Building type definitions with requirements
  BUILDING_TYPES = {
    mineral_extractor: {
      name: "Mineral Extractor",
      race: "krog",         # Krog excels at extraction
      function: "extraction",
      tier: 1,
      credits: 500,
      materials: { iron: 20, silicon: 10 },
      construction_time: 30.minutes,
      tutorial_available: true,
      description: "Extracts minerals from planetary deposits"
    },
    water_extractor: {
      name: "Water Extractor",
      race: "myrmidon",
      function: "extraction",
      tier: 1,
      credits: 400,
      materials: { iron: 15, silicon: 5 },
      construction_time: 20.minutes,
      tutorial_available: true,
      description: "Harvests water from ice or ocean worlds"
    },
    warehouse: {
      name: "Warehouse",
      race: "vex",
      function: "logistics",
      tier: 1,
      credits: 600,
      materials: { iron: 30, silicon: 15 },
      construction_time: 45.minutes,
      tutorial_available: true,
      description: "Stores goods and resources"
    },
    refinery: {
      name: "Ore Refinery",
      race: "krog",
      function: "refining",
      tier: 2,
      credits: 2000,
      materials: { iron: 100, silicon: 50, copper: 25 },
      construction_time: 2.hours,
      tutorial_available: false,
      description: "Processes raw ore into refined metals"
    },
    defense_platform: {
      name: "Defense Platform",
      race: "solari",
      function: "defense",
      tier: 2,
      credits: 3000,
      materials: { iron: 80, silicon: 40, titanium: 20 },
      construction_time: 3.hours,
      tutorial_available: false,
      description: "Protects system from hostile forces"
    }
  }.freeze

  # Construct a new building
  # @param user [User] The user constructing the building
  # @param system [System] The system to build in
  # @param building_type [Symbol] Type of building to construct
  # @param ship [Ship] Ship providing materials
  # @return [ConstructionResult]
  def self.construct(user:, system:, building_type:, ship:)
    new(user: user, system: system, building_type: building_type, ship: ship).construct
  end

  # Complete a building's construction
  # @param building [Building] Building to complete
  # @return [ConstructionResult]
  def self.complete_construction(building:)
    new(building: building).complete_construction
  end

  # Get available building types for a tutorial phase
  # @param tutorial_phase [Symbol] The user's current phase
  # @return [Array<Symbol>]
  def self.available_building_types(tutorial_phase:)
    case tutorial_phase
    when :proving_ground, "proving_ground"
      BUILDING_TYPES.select { |_, v| v[:tutorial_available] }.keys
    when :graduated, "graduated"
      BUILDING_TYPES.keys
    else
      []  # Cradle phase - no building yet
    end
  end

  # Get requirements for a building type
  # @param building_type [Symbol] The building type
  # @return [Hash]
  def self.requirements_for(building_type)
    type_def = BUILDING_TYPES[building_type]
    return nil unless type_def

    {
      credits: type_def[:credits],
      materials: type_def[:materials],
      construction_time: type_def[:construction_time].to_i
    }
  end

  def initialize(user: nil, system: nil, building_type: nil, ship: nil, building: nil)
    @user = user
    @system = system
    @building_type = building_type
    @ship = ship
    @building = building
    @type_def = BUILDING_TYPES[@building_type] if @building_type
  end

  def construct
    return ConstructionResult.failure("Invalid building type") unless @type_def
    return ConstructionResult.failure("Ship must be docked in target system") unless ship_in_system?
    return ConstructionResult.failure("Insufficient credits (need #{@type_def[:credits]})") unless sufficient_credits?
    return ConstructionResult.failure("Missing materials: #{missing_materials_message}") unless sufficient_materials?

    ActiveRecord::Base.transaction do
      consume_resources!
      building = create_building!

      tutorial_milestone = check_tutorial_milestone
      ticket = check_colonial_ticket_unlock

      ConstructionResult.success(building: building, tutorial_milestone: tutorial_milestone, ticket: ticket)
    end
  rescue ActiveRecord::RecordInvalid => e
    ConstructionResult.failure("Failed to create building: #{e.message}")
  end

  def complete_construction
    return ConstructionResult.failure("Building not found") unless @building
    return ConstructionResult.failure("Construction not finished yet") unless construction_finished?
    return ConstructionResult.failure("Building not under construction") unless @building.status == "under_construction"

    @building.update!(status: "active")
    ConstructionResult.success(building: @building)
  rescue ActiveRecord::RecordInvalid => e
    ConstructionResult.failure("Failed to complete construction: #{e.message}")
  end

  private

  def ship_in_system?
    return false unless @ship
    return false unless @ship.current_system

    @ship.current_system == @system && @ship.status == "docked"
  end

  def sufficient_credits?
    @user.credits >= @type_def[:credits]
  end

  def sufficient_materials?
    missing_materials.empty?
  end

  def missing_materials
    missing = {}
    @type_def[:materials].each do |material, required|
      cargo_amount = @ship.cargo[material.to_s].to_i
      if cargo_amount < required
        missing[material] = required - cargo_amount
      end
    end
    missing
  end

  def missing_materials_message
    missing_materials.map { |m, amt| "#{amt} #{m}" }.join(", ")
  end

  def consume_resources!
    # Deduct credits
    @user.update!(credits: @user.credits - @type_def[:credits])

    # Deduct materials from ship cargo
    new_cargo = @ship.cargo.dup
    @type_def[:materials].each do |material, required|
      current = new_cargo[material.to_s].to_i
      new_cargo[material.to_s] = current - required
    end
    @ship.update!(cargo: new_cargo)
  end

  def create_building!
    Building.create!(
      user: @user,
      system: @system,
      name: @type_def[:name],
      race: @type_def[:race],
      function: @type_def[:function],
      tier: @type_def[:tier],
      status: "under_construction",
      construction_ends_at: Time.current + @type_def[:construction_time],
      specialization: building_specialization
    )
  end

  # Determine specialization for extraction buildings
  # Uses the first available mineral in the system
  def building_specialization
    return nil unless @type_def[:function] == "extraction"

    @system&.available_minerals&.first
  end

  def construction_finished?
    return false unless @building.construction_ends_at

    @building.construction_ends_at <= Time.current
  end

  def check_tutorial_milestone
    return nil unless @user.proving_ground?

    # Check if this is user's first building
    if @user.buildings.count == 1  # Just created the first one
      :first_building
    else
      nil
    end
  end

  # Check if building construction completes Proving Ground requirements
  # and automatically unlock Colonial Ticket if so
  def check_colonial_ticket_unlock
    return nil unless @user.proving_ground?

    result = ColonialTicketService.check_and_unlock_if_ready(user: @user)
    result.ticket if result.success?
  end
end
