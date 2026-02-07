require "test_helper"

class LeaderboardCacheJobTest < ActiveJob::TestCase
  test "warms all period caches" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    LeaderboardCacheJob.perform_now

    ExplorationLeaderboard::PERIODS.each do |period|
      assert_not_nil Rails.cache.read("leaderboard/exploration/#{period}"),
        "Expected cache for #{period} to be warmed"
    end
  ensure
    Rails.cache = original_cache
  end
end
