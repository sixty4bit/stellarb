# frozen_string_literal: true

# Ensure recruit pool is ready on server startup
# This initializer runs after Rails is fully loaded and ensures:
# 1. Expired recruits are cleaned up
# 2. Fresh recruits are generated if pool is empty/stale
# 3. Next rotation job is scheduled
#
# Safe to run on every boot (idempotent)

Rails.application.config.after_initialize do
  # Only run in server context, not during:
  # - rake tasks (migrations, asset precompile, etc.)
  # - rails console (unless explicitly wanted)
  # - test environment (tests handle their own setup)
  
  next if Rails.env.test?
  next if defined?(Rails::Console)
  next unless defined?(Rails::Server) || ENV["WEB_CONCURRENCY"].present?

  # Delay slightly to ensure all models are loaded and DB is ready
  Thread.new do
    sleep 5 # Wait for server to stabilize
    
    Rails.logger.info "[RecruiterRefresh] Checking recruit pool on startup..."
    
    begin
      RecruiterRefreshJob.ensure_pool_ready
      Rails.logger.info "[RecruiterRefresh] Recruit pool ready, rotation scheduled"
    rescue => e
      Rails.logger.error "[RecruiterRefresh] Failed to initialize recruit pool: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end
end
