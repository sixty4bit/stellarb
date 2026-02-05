# frozen_string_literal: true

require "test_helper"

class OnboardingStepsTest < ActionDispatch::IntegrationTest
  def setup
    @system = System.create!(x: 0, y: 0, z: 0, name: "Test System")
    @user = User.create!(
      email: "steps@test.com",
      name: "StepsUser",
      profile_completed_at: Time.current
    )
    sign_in_as(@user)
  end

  # ===========================================
  # Ships Tour Step (Step 2)
  # ===========================================

  test "ships_tour step shows overlay on ships page" do
    @user.update!(onboarding_step: "ships_tour")

    get ships_path

    assert_response :success
    assert_select "#onboarding-sidebar"
    assert_select "[data-onboarding-step-value='ships_tour']"
  end

  test "ships_tour step highlights ships menu item" do
    @user.update!(onboarding_step: "ships_tour")

    get ships_path

    assert_response :success
    # The highlight is applied via JavaScript, but we can verify the data attribute
    assert_select "[data-onboarding-highlight-value*='ships']"
  end

  test "advancing from ships_tour goes to navigation_tutorial" do
    @user.update!(onboarding_step: "ships_tour")

    post advance_onboarding_path

    @user.reload
    assert_equal "navigation_tutorial", @user.onboarding_step
    assert_redirected_to navigation_index_path
  end

  # ===========================================
  # Navigation Tutorial Step (Step 3)
  # ===========================================

  test "navigation_tutorial step shows overlay on navigation page" do
    @user.update!(onboarding_step: "navigation_tutorial")

    get navigation_index_path

    assert_response :success
    assert_select "#onboarding-sidebar"
    assert_select "[data-onboarding-step-value='navigation_tutorial']"
  end

  test "advancing from navigation_tutorial goes to trade_routes" do
    @user.update!(onboarding_step: "navigation_tutorial")

    post advance_onboarding_path

    @user.reload
    assert_equal "trade_routes", @user.onboarding_step
    assert_redirected_to routes_path
  end

  # ===========================================
  # Trade Routes Step (Step 4 - Key Goal)
  # ===========================================

  test "trade_routes step shows overlay on routes page" do
    @user.update!(onboarding_step: "trade_routes")

    get routes_path

    assert_response :success
    assert_select "#onboarding-sidebar"
    assert_select "[data-onboarding-step-value='trade_routes']"
  end

  test "trade_routes step highlights routes menu item" do
    @user.update!(onboarding_step: "trade_routes")

    get routes_path

    assert_response :success
    assert_select "[data-onboarding-highlight-value*='routes']"
  end

  test "advancing from trade_routes goes to workers_overview" do
    @user.update!(onboarding_step: "trade_routes")

    post advance_onboarding_path

    @user.reload
    assert_equal "workers_overview", @user.onboarding_step
    assert_redirected_to workers_path
  end

  # ===========================================
  # Workers Overview Step (Step 5)
  # ===========================================

  test "workers_overview step shows overlay on workers page" do
    @user.update!(onboarding_step: "workers_overview")

    get workers_path

    assert_response :success
    assert_select "#onboarding-sidebar"
    assert_select "[data-onboarding-step-value='workers_overview']"
  end

  test "advancing from workers_overview goes to inbox_introduction" do
    @user.update!(onboarding_step: "workers_overview")

    post advance_onboarding_path

    @user.reload
    assert_equal "inbox_introduction", @user.onboarding_step
    assert_redirected_to inbox_index_path
  end

  # ===========================================
  # Inbox Introduction Step (Step 6 - Final)
  # ===========================================

  test "inbox_introduction step shows overlay on inbox page" do
    @user.update!(onboarding_step: "inbox_introduction")

    get inbox_index_path

    assert_response :success
    assert_select "#onboarding-sidebar"
    assert_select "[data-onboarding-step-value='inbox_introduction']"
  end

  test "advancing from inbox_introduction completes onboarding" do
    @user.update!(onboarding_step: "inbox_introduction")

    post advance_onboarding_path

    @user.reload
    assert @user.onboarding_complete?
    assert_redirected_to inbox_index_path
  end

  test "completed onboarding no longer shows overlay" do
    @user.skip_onboarding!

    get ships_path

    assert_response :success
    assert_select "#onboarding-sidebar", count: 0
  end

  # ===========================================
  # Step Content Verification
  # ===========================================

  test "each step shows appropriate title" do
    step_titles = {
      "profile_setup" => "Welcome to StellArb!",
      "ships_tour" => "Your Fleet Awaits",
      "navigation_tutorial" => "Charting the Stars",
      "trade_routes" => "Trade Routes",
      "workers_overview" => "Your Crew",
      "inbox_introduction" => "Your Command Center"
    }

    step_titles.each do |step, expected_title|
      @user.update!(onboarding_step: step)
      @user.update!(onboarding_completed_at: nil)

      get inbox_index_path

      assert_response :success
      assert_match expected_title, response.body, "Step #{step} should show title '#{expected_title}'"
    end
  end
end
