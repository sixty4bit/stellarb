# frozen_string_literal: true

class LeaderboardsController < ApplicationController
  def index
    @periods = {
      today: ExplorationLeaderboard.top(period: :today),
      this_week: ExplorationLeaderboard.top(period: :this_week),
      this_month: ExplorationLeaderboard.top(period: :this_month),
      this_year: ExplorationLeaderboard.top(period: :this_year),
      all_time: ExplorationLeaderboard.top(period: :all_time)
    }
  end
end
