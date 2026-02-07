class LeaderboardCacheJob < ApplicationJob
  queue_as :default

  def perform
    ExplorationLeaderboard::PERIODS.each do |period|
      ExplorationLeaderboard.top(period: period)
    end
  end
end
