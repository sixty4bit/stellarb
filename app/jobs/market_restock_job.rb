# frozen_string_literal: true

# Replenishes market inventory for all systems with existing inventory records.
# Runs hourly via Solid Queue recurring schedule.
class MarketRestockJob < ApplicationJob
  queue_as :default

  def perform
    restocked_count = 0
    total_units = 0

    MarketInventory.where("quantity < max_quantity").find_each do |inventory|
      units_added = inventory.restock!
      if units_added > 0
        restocked_count += 1
        total_units += units_added
      end
    end

    Rails.logger.info "[MarketRestockJob] Restocked #{restocked_count} inventories with #{total_units} total units"
  end
end
