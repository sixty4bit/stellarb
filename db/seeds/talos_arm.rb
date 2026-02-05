# Talos Arm Tutorial Region Seeds
# These systems provide the initial trading loop for new players
# Located within easy travel distance of The Cradle (0,0,0)

module Seeds
  class TalosArm
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
        # Cheap ore, expensive food/water
        price_deltas: {
          "ore" => -20,      # Cheap (base 50 - 20 = 30)
          "food" => 15,      # Expensive (base 25 + 15 = 40)
          "water" => 10,     # Slightly expensive
          "fuel" => 0        # Normal
        }
      },
      {
        name: "Verdant Gardens",
        coords: [2, 3, 1],
        description: "An agricultural hub with hydroponics bays. They need ore for expansion.",
        properties: {
          star_type: "yellow_dwarf",
          planet_count: 5,
          hazard_level: 5,
          security_level: "high",
          specialty: "agriculture"
        },
        # Cheap food/water, expensive ore
        price_deltas: {
          "ore" => 25,       # Expensive (base 50 + 25 = 75)
          "food" => -15,     # Cheap (base 25 - 15 = 10)
          "water" => -10,    # Cheap
          "fuel" => 5        # Slightly expensive
        }
      },
      {
        name: "Nexus Hub",
        coords: [1, 3, 2],
        description: "A trade hub with electronics manufacturing. Needs raw materials.",
        properties: {
          star_type: "blue_giant",
          planet_count: 4,
          hazard_level: 15,
          security_level: "medium",
          specialty: "manufacturing"
        },
        # Cheap electronics, expensive ore and fuel
        price_deltas: {
          "electronics" => -50,  # Cheap (base 200 - 50 = 150)
          "ore" => 30,           # Expensive
          "fuel" => -15,         # Cheaper fuel
          "food" => 5            # Slightly expensive
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
        price_deltas: {
          "fuel" => -30,     # Very cheap (base 100 - 30 = 70)
          "food" => 20,      # Expensive
          "water" => 5,      # Slightly expensive
          "medicine" => -20  # Cheaper medicine (workers get injured)
        }
      }
    ].freeze

    class << self
      def seed!
        puts "Seeding Talos Arm tutorial systems..."
        
        # Ensure The Cradle exists
        cradle = System.cradle
        puts "  ✓ The Cradle at (0,0,0)"

        SYSTEMS.each do |config|
          system = create_or_update_system(config)
          apply_price_deltas(system, config[:price_deltas])
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
            talos_arm: true
          )
        )
        system.save!
        system
      end

      def apply_price_deltas(system, deltas)
        return unless deltas
        
        deltas.each do |commodity, delta|
          price_delta = PriceDelta.find_or_initialize_by(
            system: system,
            commodity: commodity
          )
          price_delta.update!(delta_cents: delta * 100)  # Store in cents
        end
      end
    end
  end
end

# Allow running directly: rails runner db/seeds/talos_arm.rb
if __FILE__ == $PROGRAM_NAME
  Seeds::TalosArm.seed!
end
