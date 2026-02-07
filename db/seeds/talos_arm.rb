# frozen_string_literal: true

# Talos Arm Tutorial Region Seeds
# These systems provide the initial trading loop for new players
# Located within easy travel distance of The Cradle (0,0,0)

module Seeds
  class TalosArm
    # Base prices shared across all tutorial systems (in credits)
    # Using minerals from the Minerals module
    BASE_PRICES = {
      "Iron" => 10,
      "Copper" => 15,
      "Aluminum" => 12,
      "Silicon" => 18,
      "Carbon" => 8,
      "Sulfur" => 6,
      "Graphite" => 14,
      "Nickel" => 25,
      "Zinc" => 22,
      "Tungsten" => 55
    }.freeze

    # System configurations for the tutorial trade loop
    SYSTEMS = [
      {
        name: "Mira Station",
        coords: [3, 1, 0],
        description: "A mining outpost rich in raw ore. Miners here need processed metals.",
        properties: {
          star_type: "red_dwarf",
          planet_count: 3,
          hazard_level: 10,
          security_level: "high",
          specialty: "mining"
        },
        # Cheap Iron/Copper (mining), expensive processed metals like Tungsten
        price_adjustments: {
          "Iron" => -5,
          "Copper" => -7,
          "Tungsten" => 15
        }
      },
      {
        name: "Verdant Gardens",
        coords: [-2, 3, 0],
        description: "An agricultural hub with hydroponics bays. They need metals for expansion.",
        properties: {
          star_type: "yellow_dwarf",
          planet_count: 5,
          hazard_level: 5,
          security_level: "high",
          specialty: "agriculture"
        },
        # Expensive Iron (need it), cheap Carbon (byproduct of agriculture)
        price_adjustments: {
          "Iron" => 5,
          "Copper" => 8,
          "Carbon" => -3
        }
      },
      {
        name: "Nexus Hub",
        coords: [-1, -2, 3],
        description: "A trade hub and transit point. High-value metals are in demand here.",
        properties: {
          star_type: "blue_giant",
          planet_count: 4,
          hazard_level: 15,
          security_level: "medium",
          specialty: "trade"
        },
        # Tungsten in high demand, Graphite cheap
        price_adjustments: {
          "Graphite" => -5,
          "Tungsten" => 25,
          "Copper" => 5
        }
      },
      {
        name: "Beacon Refinery",
        coords: [2, -3, 1],
        description: "A refinery station. They produce refined metals but need raw materials.",
        properties: {
          star_type: "orange_dwarf",
          planet_count: 2,
          hazard_level: 20,
          security_level: "medium",
          specialty: "refining"
        },
        # Cheap Tungsten (they produce it), expensive raw Iron
        price_adjustments: {
          "Tungsten" => -20,
          "Iron" => 8,
          "Nickel" => 10
        }
      }
    ].freeze

    class << self
      NPC_BUILDINGS = {
        "The Cradle" => [
          { name: "Civic Center",    function: "civic",     tier: 2 },
          { name: "Logistics Hub",   function: "logistics", tier: 1 },
          { name: "Defense Station", function: "defense",   tier: 1 }
        ],
        "Mira Station" => [
          { name: "Ore Extraction",  function: "extraction", tier: 2, specialization: "Iron" },
          { name: "Mira Depot",      function: "logistics",  tier: 1 },
          { name: "Mira Defense",    function: "defense",     tier: 1 }
        ],
        "Verdant Gardens" => [
          { name: "Garden Civic",    function: "civic",      tier: 1 },
          { name: "Garden Depot",    function: "logistics",  tier: 1 },
          { name: "Garden Defense",  function: "defense",    tier: 1 }
        ],
        "Nexus Hub" => [
          { name: "Trade Center",    function: "civic",      tier: 2 },
          { name: "Nexus Logistics", function: "logistics",  tier: 2 },
          { name: "Nexus Defense",   function: "defense",    tier: 1 }
        ],
        "Beacon Refinery" => [
          { name: "Beacon Extractor", function: "extraction", tier: 1, specialization: "Tungsten" },
          { name: "Beacon Depot",    function: "logistics",  tier: 1 },
          { name: "Beacon Defense",  function: "defense",     tier: 1 }
        ]
      }.freeze

      def seed!
        puts "Seeding Talos Arm tutorial systems..."

        # Ensure The Cradle exists
        cradle = System.cradle
        initialize_market_inventory(cradle)
        seed_npc_buildings(cradle)
        puts "  ✓ The Cradle at (0,0,0)"

        SYSTEMS.each do |config|
          system = create_or_update_system(config)
          apply_price_deltas(system, config[:price_adjustments])
          initialize_market_inventory(system)
          seed_npc_buildings(system)
          puts "  ✓ #{system.name} at (#{config[:coords].join(',')})"
        end

        puts "Talos Arm seeding complete! #{SYSTEMS.length} systems created."
      end

      def reset!
        puts "Resetting Talos Arm systems..."
        SYSTEMS.each do |config|
          x, y, z = config[:coords]
          system = System.find_by(x: x, y: y, z: z)
          if system
            system.price_deltas.destroy_all
            system.market_inventories.destroy_all
            system.destroy
            puts "  ✗ Removed #{config[:name]}"
          end
        end
        puts "Talos Arm reset complete."
      end

      private

      def create_or_update_system(config)
        x, y, z = config[:coords]

        system = System.find_or_initialize_by(x: x, y: y, z: z)
        system.assign_attributes(
          name: config[:name],
          properties: config[:properties].merge(
            description: config[:description],
            is_tutorial_zone: true,
            talos_arm: true,
            base_prices: BASE_PRICES
          )
        )
        system.save!
        system
      end

      # Create PriceDeltas for the price adjustments
      # Converts credit adjustments to cents for storage
      def apply_price_deltas(system, adjustments)
        return unless adjustments

        adjustments.each do |commodity, adjustment|
          # Store as cents (adjustment * 100)
          PriceDelta.find_or_initialize_by(system: system, commodity: commodity).tap do |delta|
            delta.delta_cents = adjustment * 100
            delta.save!
          end
        end
      end

      def seed_npc_buildings(system)
        buildings = NPC_BUILDINGS[system.name]
        return unless buildings

        buildings.each do |config|
          existing = Building.find_by(system: system, name: config[:name])
          next if existing

          b = Building.new(
            system: system,
            name: config[:name],
            user: nil,
            function: config[:function],
            race: "vex",
            tier: config[:tier],
            status: "active"
          )
          b.specialization = config[:specialization] if config[:specialization]
          b.save!(validate: false) # NPC buildings bypass player validations
        end
      end

      def initialize_market_inventory(system)
        # Create inventory for available minerals
        available_minerals = MineralAvailability.for_system(
          star_type: system.properties&.dig("star_type") || "yellow_dwarf",
          x: system.x,
          y: system.y,
          z: system.z
        )

        available_minerals.each do |mineral|
          MarketInventory.find_or_create_by!(system: system, commodity: mineral[:name]) do |inv|
            inv.quantity = 500
            inv.max_quantity = 1000
            inv.restock_rate = 10
          end
        end
      end
    end
  end
end

# Allow running directly: rails runner db/seeds/talos_arm.rb
if __FILE__ == $PROGRAM_NAME
  Seeds::TalosArm.seed!
end
