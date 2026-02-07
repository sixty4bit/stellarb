# frozen_string_literal: true

require "test_helper"

class LeaderboardTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "leaderboard page renders all period sections" do
    get leaderboards_path
    assert_response :success

    assert_select "turbo-frame#content_panel"
    assert_select "h2", text: /Today/
    assert_select "h2", text: /This Week/
    assert_select "h2", text: /This Month/
    assert_select "h2", text: /This Year/
    assert_select "h2", text: /All Time/
  end

  test "leaderboard shows empty state when no explorers" do
    get leaderboards_path
    assert_response :success

    assert_select "p", text: /No explorers yet/
  end

  test "navigation menu includes leaderboard link" do
    get leaderboards_path
    assert_response :success

    assert_select "a[href=?]", leaderboards_path
  end
end
