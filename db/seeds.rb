# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Load seed modules
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |f| require f }

# ===========================================
# Core Systems
# ===========================================

# Ensure The Cradle exists (origin system at 0,0,0)
System.cradle
puts "✓ The Cradle initialized"

# ===========================================
# Tutorial Region: Talos Arm
# ===========================================

Seeds::TalosArm.seed!
