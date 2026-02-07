class ExplorationLeaderboard
  PERIODS = %i[all_time today this_week this_month this_year].freeze

  def self.top(period:, limit: 5)
    expires = period == :today ? 5.minutes : 24.hours

    Rails.cache.fetch("leaderboard/exploration/#{period}", expires_in: expires) do
      scope = ExploredCoordinate.all
      scope = scope.where(created_at: period_range(period)) unless period == :all_time

      rows = scope.group(:user_id).order(Arel.sql("COUNT(*) DESC")).limit(limit).count
      users = User.where(id: rows.keys).index_by(&:id)

      rows.map { |user_id, count| { user: users[user_id], count: count } }
    end
  end

  def self.period_range(period)
    case period
    when :today      then Date.current.all_day
    when :this_week  then Date.current.beginning_of_week..Time.current
    when :this_month then Date.current.beginning_of_month..Time.current
    when :this_year  then Date.current.beginning_of_year..Time.current
    end
  end

  private_class_method :period_range
end
