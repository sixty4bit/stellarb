require "test_helper"

class OnboardingHelperTest < ActionView::TestCase
  test "inbox_introduction step config exists" do
    config = onboarding_step_config("inbox_introduction")

    assert_equal "Your Command Center", config[:title]
    assert_match /inbox/i, config[:description]
    assert_equal "📬", config[:icon]
    assert_equal "Complete Tutorial", config[:action_text]
  end

  test "inbox_introduction is in onboarding steps" do
    assert_includes User::ONBOARDING_STEPS, "inbox_introduction"
  end

  test "inbox_introduction is the final step" do
    assert_equal "inbox_introduction", User::ONBOARDING_STEPS.last
  end

  test "inbox_introduction comes after workers_overview" do
    workers_index = User::ONBOARDING_STEPS.index("workers_overview")
    inbox_index = User::ONBOARDING_STEPS.index("inbox_introduction")

    assert_equal workers_index + 1, inbox_index
  end

  test "onboarding has 6 steps ending at inbox" do
    assert_equal 6, User::ONBOARDING_STEPS.length
    assert_equal %w[profile_setup ships_tour navigation_tutorial trade_routes workers_overview inbox_introduction], User::ONBOARDING_STEPS
  end
end
