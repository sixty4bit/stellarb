# frozen_string_literal: true

# Daily job to check for inactive system owners and manage auctions
#
# Responsibilities:
# 1. Send warning messages to owners approaching seizure threshold
# 2. Create auctions for systems with inactive owners (30+ days)
# 3. Finalize ended auctions (transfer ownership, burn bids)
class SystemOwnershipCheckJob < ApplicationJob
  queue_as :default

  INACTIVITY_THRESHOLD = SystemAuction::INACTIVITY_THRESHOLD_DAYS.days
  WARNING_DAYS = SystemAuction::WARNING_DAYS

  def perform
    Rails.logger.info "[SystemOwnershipCheck] Starting daily ownership check"

    finalize_ended_auctions
    check_inactive_owners
    send_warnings

    Rails.logger.info "[SystemOwnershipCheck] Completed"
  end

  private

  # Finalize any auctions that have ended
  def finalize_ended_auctions
    SystemAuction.ended.find_each do |auction|
      Rails.logger.info "[SystemOwnershipCheck] Finalizing auction for #{auction.system.name}"
      auction.complete!
    rescue => e
      Rails.logger.error "[SystemOwnershipCheck] Error finalizing auction #{auction.id}: #{e.message}"
    end
  end

  # Check for systems whose owners have been inactive for 30+ days
  def check_inactive_owners
    threshold = INACTIVITY_THRESHOLD.ago

    inactive_systems.where("systems.owner_last_visit_at <= ?", threshold).find_each do |system|
      next if system_has_active_auction?(system)

      Rails.logger.info "[SystemOwnershipCheck] Creating auction for inactive system: #{system.name}"
      create_auction_for_system(system)
    end
  end

  # Send warnings to owners approaching the threshold
  def send_warnings
    WARNING_DAYS.each do |days_before|
      send_warning_for_days(days_before)
    end
  end

  def send_warning_for_days(days_before)
    threshold_date = (INACTIVITY_THRESHOLD - days_before.days).ago
    window_start = threshold_date - 12.hours
    window_end = threshold_date + 12.hours

    # Find systems where owner was last active within the warning window
    systems_to_warn = inactive_systems
      .where(owner_last_visit_at: window_start..window_end)
      .where.not(id: systems_with_active_auctions)

    systems_to_warn.find_each do |system|
      next if already_warned?(system, days_before)

      send_seizure_warning(system, days_before)
    end
  end

  def inactive_systems
    System.where.not(owner_id: nil).where.not(owner_last_visit_at: nil)
  end

  def systems_with_active_auctions
    SystemAuction.where(status: %w[pending active]).select(:system_id)
  end

  def system_has_active_auction?(system)
    SystemAuction.for_system(system).where(status: %w[pending active]).exists?
  end

  def already_warned?(system, days_before)
    # Check if we already sent a warning for this threshold
    Message.where(
      user: system.owner,
      category: "seizure_warning"
    ).where(
      "title LIKE ?", "%#{system.name}%"
    ).where(
      "body LIKE ?", "%#{days_before} day%"
    ).where(
      "created_at > ?", 24.hours.ago
    ).exists?
  end

  def send_seizure_warning(system, days_before)
    Message.create!(
      user: system.owner,
      from: "Galactic Trade Authority",
      title: "Seizure Warning: #{system.name}",
      body: seizure_warning_body(system, days_before),
      category: "seizure_warning",
      urgent: days_before <= 1
    )

    Rails.logger.info "[SystemOwnershipCheck] Sent #{days_before}-day warning for #{system.name}"
  end

  def seizure_warning_body(system, days_before)
    if days_before == 1
      "URGENT: #{system.name} will be seized in approximately 1 day due to inactivity. " \
      "Visit the system immediately to maintain ownership."
    else
      "Warning: #{system.name} will be seized in approximately #{days_before} days due to inactivity. " \
      "Visit the system to maintain ownership and reset the inactivity timer."
    end
  end

  def create_auction_for_system(system)
    SystemAuction.create_for_inactive_system!(system)

    Message.create!(
      user: system.owner,
      from: "Galactic Trade Authority",
      title: "System Seized: #{system.name}",
      body: "#{system.name} has been seized due to extended inactivity and is now up for auction. " \
            "The auction will run for #{SystemAuction::DURATION_HOURS} hours. " \
            "Visit the system to cancel the auction and reclaim ownership.",
      category: "auction",
      urgent: true
    )
  rescue => e
    Rails.logger.error "[SystemOwnershipCheck] Error creating auction for #{system.name}: #{e.message}"
  end
end
