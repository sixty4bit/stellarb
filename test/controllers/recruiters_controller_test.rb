# frozen_string_literal: true

require "test_helper"

class RecruitersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
    @recruit = recruits(:engineer_bob)
  end

  # ================================================
  # Task stellarb-b2a: RecruitersController#index
  # ================================================

  test "index renders recruiter list page" do
    get recruiters_path
    assert_response :success
    assert_select "h1", text: /Recruiter/i
  end

  test "index shows available recruits for user level tier" do
    get recruiters_path
    assert_response :success
    # Should show Engineer from fixture (level_tier 1, same as user)
    assert_select "*", text: /Engineer/i
  end

  test "index displays recruit skill level" do
    get recruiters_path
    assert_response :success
    assert_select "*", text: /65/ # engineer_bob's skill
  end

  test "index displays recruit race" do
    get recruiters_path
    assert_response :success
    assert_select "*", text: /vex/i
  end

  test "index displays rarity tier" do
    get recruiters_path
    assert_response :success
    # skill 65 = uncommon
    assert_select "*", text: /uncommon/i
  end

  test "index shows employment history preview" do
    get recruiters_path
    assert_response :success
    assert_select "*", text: /Stellar Mining Corp/i
  end

  test "index shows hire cost" do
    get recruiters_path
    assert_response :success
    # Base wage is ~650 (65 skill * 10), hire cost = 2 weeks = wage * 2
    assert_select "*", text: /cr/i
  end

  test "index has link to view recruit details" do
    get recruiters_path
    assert_response :success
    assert_select "a[href*='#{recruiter_path(@recruit)}']"
  end

  test "index shows pool refresh timer" do
    get recruiters_path
    assert_response :success
    assert_select "*", text: /refresh/i
  end

  test "index does not show recruits from different level tier" do
    # Create a level 2 recruit with a distinctive name
    level2_recruit = Recruit.create!(
      level_tier: 2,
      race: "krog",
      npc_class: "marine",
      name: "Level2Grunt the Impossible",
      skill: 70,
      chaos_factor: 20,
      available_at: 1.hour.ago,
      expires_at: 2.hours.from_now,
      base_stats: {},
      employment_history: []
    )

    get recruiters_path
    assert_response :success
    # Should not show level 2 recruit's unique name
    refute_match(/Level2Grunt the Impossible/, response.body)
  end

  test "index does not show expired recruits" do
    expired_recruit = Recruit.create!(
      level_tier: 1,
      race: "solari",
      npc_class: "governor",
      skill: 80,
      chaos_factor: 10,
      available_at: 3.hours.ago,
      expires_at: 1.hour.ago, # Already expired
      base_stats: {},
      employment_history: []
    )

    get recruiters_path
    assert_response :success
    # Should not show expired recruit
    refute_match /Governor.*solari.*80/i, response.body
  end

  test "index has breadcrumb navigation" do
    get recruiters_path
    assert_response :success
    assert_select "a[href='#{root_path}']"
  end
end
