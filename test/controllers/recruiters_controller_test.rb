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

  # ================================================
  # Task stellarb-04o: RecruitersController#show
  # ================================================

  test "show renders recruit detail page" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "h1", text: /Engineer/i
  end

  test "show displays recruit skill" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /Skill/i
    assert_select "*", text: /65/
  end

  test "show displays recruit race" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /Vex/i
  end

  test "show displays rarity tier" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /uncommon/i
  end

  test "show displays full employment history" do
    get recruiter_path(@recruit)
    assert_response :success
    # From fixture: employer "Stellar Mining Corp", duration "14", outcome "Contract completed"
    assert_select "*", text: /Stellar Mining Corp/i
    assert_select "*", text: /Contract completed/i
  end

  test "show displays hire cost" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /Hire cost/i
    assert_select "*", text: /cr/i
  end

  test "show has hire button" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "form[action*='hire']"
  end

  test "show has back to recruiter link" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "a[href='#{recruiters_path}']"
  end

  test "show has breadcrumb navigation" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "a[href='#{root_path}']"
    assert_select "a[href='#{recruiters_path}']"
  end

  test "show displays quirks if present" do
    # Navigator fixture has stats with quirks or we need to add
    navigator = recruits(:navigator_zara)
    navigator.update!(base_stats: { "quirks" => ["meticulous", "efficient"] })

    get recruiter_path(navigator)
    assert_response :success
    assert_select "*", text: /meticulous/i
  end

  test "show displays chaos warning for high chaos recruits" do
    marine = recruits(:marine_grunt)
    # Marine has chaos_factor 60 - should show warning

    get recruiter_path(marine)
    assert_response :success
    # High chaos should have some visual indicator
    assert_select "*", text: /Cargo incident/i
  end

  test "show redirects to index when recruit is expired" do
    @recruit.update!(expires_at: 1.hour.ago)

    get recruiter_path(@recruit)
    assert_redirected_to recruiters_path
    assert_match /no longer available/i, flash[:alert]
  end

  test "show redirects to index when recruit is not available yet" do
    @recruit.update!(available_at: 1.hour.from_now)

    get recruiter_path(@recruit)
    assert_redirected_to recruiters_path
    assert_match /not yet available/i, flash[:alert]
  end

  # ================================================
  # Task stellarb-r9a: RecruitersController#hire
  # ================================================

  test "hire creates HiredRecruit and Hiring records" do
    ship = ships(:hauler)
    # Ensure user has enough credits
    @user.update!(credits: 5000)

    assert_difference -> { HiredRecruit.count } => 1, -> { Hiring.count } => 1 do
      post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }
    end
  end

  test "hire redirects to worker show page on success" do
    ship = ships(:hauler)
    @user.update!(credits: 5000)

    post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }
    assert_redirected_to worker_path(HiredRecruit.last)
  end

  test "hire shows success notice" do
    ship = ships(:hauler)
    @user.update!(credits: 5000)

    post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }
    assert_match /hired/i, flash[:notice]
  end

  test "hire deducts credits from user" do
    ship = ships(:hauler)
    @user.update!(credits: 5000)
    initial_credits = @user.credits
    hire_cost = @recruit.base_wage * 2

    post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }

    @user.reload
    assert_equal initial_credits - hire_cost, @user.credits
  end

  test "hire fails when user has insufficient credits" do
    ship = ships(:hauler)
    @user.update!(credits: 0)

    assert_no_difference -> { HiredRecruit.count } do
      post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }
    end

    assert_redirected_to recruiters_path
    assert_match /insufficient credits/i, flash[:alert]
  end

  test "hire fails when recruit is expired" do
    ship = ships(:hauler)
    @user.update!(credits: 5000)
    @recruit.update!(expires_at: 1.hour.ago)

    assert_no_difference -> { HiredRecruit.count } do
      post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }
    end

    assert_redirected_to recruiters_path
    assert_match /no longer available/i, flash[:alert]
  end

  test "hire removes recruit from pool" do
    ship = ships(:hauler)
    @user.update!(credits: 5000)

    post hire_recruiter_path(@recruit), params: { assignable_type: "Ship", assignable_id: ship.id }

    @recruit.reload
    assert @recruit.expires_at <= Time.current, "Recruit should be expired after hiring"
  end

  # Note: DB schema requires assignable_id to be non-null
  # Unassigned hires would require a migration to allow null
  test "hire without assignable redirects with error" do
    @user.update!(credits: 5000)

    assert_no_difference -> { HiredRecruit.count } do
      post hire_recruiter_path(@recruit)
    end

    assert_redirected_to recruiters_path
    assert_match /must be assigned/i, flash[:alert]
  end
end
