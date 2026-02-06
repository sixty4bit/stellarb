# Talos Arm Tutorial Region Seeds
# These systems provide the initial trading loop for new players
# Located within easy travel distance of The Cradle (0,0,0)

module Seeds
  class TalosArm
    # Base prices shared across all tutorial systems (in credits)
    # These match The Cradle's commodities for consistent trading
    BASE_PRICES = {
      "iron" => 10,
      "copper" => 15,
      "water" => 5,
      "food" => 20,
      "fuel" => 30,
      "luxury_goods" => 100
    }.freeze

    # System configurations for the tutorial trade loop
    SYSTEMS = [
      {
        name: "Mira Station",
        coords: [3, 2, 0],
        description: "A mining outpost rich in raw ore. Miners here need food and water.",
        properties: {
          star_type: "red_dwarf",
          planet_count: 3,
          hazard_level: 10,
          security_level: "high",
          specialty: "mining"
        },
        # Cheap iron/copper, expensive food/water
        price_adjustments: {
          "iron" => -5,
          "copper" => -7,
          "food" => 15,
          "water" => 3
        }
      },
      {
        name: "Verdant Gardens",
        coords: [2, 3, 1],
        description: "An agricultural hub with hydroponics bays. They need metals for expansion.",
        properties: {
          star_type: "yellow_dwarf",
          planet_count: 5,
          hazard_level: 5,
          security_level: "high",
          specialty: "agriculture"
        },
        # Cheap food/water, expensive metals
        price_adjustments: {
          "iron" => 5,
          "copper" => 8,
          "food" => -10,
          "water" => -3
        }
      },
      {
        name: "Nexus Hub",
        coords: [1, 3, 2],
        description: "A trade hub and transit point. Luxury goods are in demand here.",
        properties: {
          star_type: "blue_giant",
          planet_count: 4,
          hazard_level: 15,
          security_level: "medium",
          specialty: "trade"
        },
        # Cheap fuel, expensive luxury goods
        price_adjustments: {
          "fuel" => -10,
          "luxury_goods" => 25,
          "copper" => 5
        }
      },
      {
        name: "Beacon Refinery",
        coords: [1, 2, 1],
        description: "A fuel refinery station. They produce fuel but need food for workers.",
        properties: {
          star_type: "orange_dwarf",
          planet_count: 2,
          hazard_level: 20,
          security_level: "medium",
          specialty: "refining"
        },
        # Cheap fuel, expensive food
        price_adjustments: {
          "fuel" => -15,
          "food" => 10,
          "luxury_goods" => -20
        }
      }
    ].freeze

    class << self
      def seed!
        puts "Seeding Talos Arm tutorial systems..."

        # Ensure The Cradle exists
        cradle = System.cradle
        initialize_market_inventory(cradle)
        puts "  ✓ The Cradle at (0,0,0)"

        SYSTEMS.each do |config|
          system = create_or_update_system(config)
          initialize_market_inventory(system)
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

        # Calculate system-specific base_prices with adjustments
        system_prices = BASE_PRICES.dup
        if config[:price_adjustments]
          config[:price_adjustments].each do |commodity, adjustment|
            if system_prices[commodity]
              system_prices[commodity] = [system_prices[commodity] + adjustment, 1].max
            end
          end
        end

        system = System.find_or_initialize_by(x: x, y: y, z: z)
        system.assign_attributes(
          name: config[:name],
          properties: config[:properties].merge(
            description: config[:description],
            is_tutorial_zone: true,
            talos_arm: true,
            base_prices: system_prices
          )
        )
        system.save!
        system
      end

      def initialize_market_inventory(system)
        MarketInventory.generate_for_system(system)
      end
    end
  end
end

# Allow running directly: rails runner db/seeds/talos_arm.rb
if __FILE__ == $PROGRAM_NAME
  Seeds::TalosArm.seed!
end
