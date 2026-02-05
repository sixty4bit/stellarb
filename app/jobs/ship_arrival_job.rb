# frozen_string_literal: true

# Processes ship arrivals for all in-transit ships.
# Runs frequently (every minute) to check for ships that have
# reached their arrival_at timestamp and need to dock.
#
# This job is scheduled as a recurring task in Solid Queue.
class ShipArrivalJob < ApplicationJob
  queue_as :default

  def perform
    results = { arrivals_processed: 0 }

    # Find all ships in transit with past arrival times
    Ship.in_transit
        .where("arrival_at <= ?", Time.current)
        .find_each do |ship|
      ship.check_arrival!
      results[:arrivals_processed] += 1
    end

    Rails.logger.info "[ShipArrivalJob] Processed #{results[:arrivals_processed]} arrivals" if results[:arrivals_processed] > 0

    results
  end
end
