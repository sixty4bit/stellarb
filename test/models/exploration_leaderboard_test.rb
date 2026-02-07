require "test_helper"

class ExplorationLeaderboardTest < ActiveSupport::TestCase
  setup do
    @alice = User.create!(name: "Alice", email: "alice_lb@test.com", profile_completed_at: Time.current)
    @bob   = User.create!(name: "Bob",   email: "bob_lb@test.com",   profile_completed_at: Time.current)
    @carol = User.create!(name: "Carol", email: "carol_lb@test.com", profile_completed_at: Time.current)
  end

  test ".top returns users ordered by exploration count descending" do
    3.times { |i| ExploredCoordinate.create!(user: @alice, x: i, y: 0, z: 0) }
    1.times { |i| ExploredCoordinate.create!(user: @bob, x: i, y: 1, z: 0) }

    result = ExplorationLeaderboard.top(period: :all_time)

    assert_equal @alice, result.first[:user]
    assert_equal 3, result.first[:count]
    assert_equal @bob, result.second[:user]
    assert_equal 1, result.second[:count]
  end

  test ".top respects limit" do
    3.times { |i| ExploredCoordinate.create!(user: @alice, x: i, y: 0, z: 0) }
    2.times { |i| ExploredCoordinate.create!(user: @bob, x: i, y: 1, z: 0) }
    1.times { |i| ExploredCoordinate.create!(user: @carol, x: i, y: 2, z: 0) }

    result = ExplorationLeaderboard.top(period: :all_time, limit: 2)
    assert_equal 2, result.size
  end

  test ".top with :today only counts today's explorations" do
    ExploredCoordinate.create!(user: @alice, x: 0, y: 0, z: 0, created_at: 2.days.ago)
    ExploredCoordinate.create!(user: @bob, x: 0, y: 1, z: 0, created_at: Time.current)

    result = ExplorationLeaderboard.top(period: :today)
    assert_equal 1, result.size
    assert_equal @bob, result.first[:user]
  end

  test ".top with :this_week filters to current week" do
    ExploredCoordinate.create!(user: @alice, x: 0, y: 0, z: 0, created_at: 2.weeks.ago)
    ExploredCoordinate.create!(user: @bob, x: 0, y: 1, z: 0, created_at: Time.current)

    result = ExplorationLeaderboard.top(period: :this_week)
    assert_equal 1, result.size
    assert_equal @bob, result.first[:user]
  end

  test ".top with :this_month filters to current month" do
    ExploredCoordinate.create!(user: @alice, x: 0, y: 0, z: 0, created_at: 2.months.ago)
    ExploredCoordinate.create!(user: @bob, x: 0, y: 1, z: 0, created_at: Time.current)

    result = ExplorationLeaderboard.top(period: :this_month)
    assert_equal 1, result.size
    assert_equal @bob, result.first[:user]
  end

  test ".top with :this_year filters to current year" do
    ExploredCoordinate.create!(user: @alice, x: 0, y: 0, z: 0, created_at: 2.years.ago)
    ExploredCoordinate.create!(user: @bob, x: 0, y: 1, z: 0, created_at: Time.current)

    result = ExplorationLeaderboard.top(period: :this_year)
    assert_equal 1, result.size
    assert_equal @bob, result.first[:user]
  end

  test ".top caches results with memory store" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    ExploredCoordinate.create!(user: @alice, x: 0, y: 0, z: 0)
    result1 = ExplorationLeaderboard.top(period: :all_time)

    ExploredCoordinate.create!(user: @bob, x: 0, y: 1, z: 0)
    result2 = ExplorationLeaderboard.top(period: :all_time)

    assert_equal 1, result2.size, "Expected cached result with 1 entry"
  ensure
    Rails.cache = original_cache
  end
end
