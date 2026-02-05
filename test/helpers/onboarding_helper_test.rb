require "test_helper"

class OnboardingHelperTest < ActionView::TestCase
  test "first_trade_run step config exists" do
    config = onboarding_step_config("first_trade_run")
    
    assert_equal "Your First Trade Run", config[:title]
    assert_match /buy cheap goods/i, config[:description]
    assert_match /Mira Station/i, config[:description]
    assert_match /Verdant Gardens/i, config[:description]
    assert_equal "💸", config[:icon]
  end

  test "first_trade_run is in onboarding steps" do
    assert_includes User::ONBOARDING_STEPS, "first_trade_run"
  end

  test "first_trade_run comes after navigation_tutorial" do
    nav_index = User::ONBOARDING_STEPS.index("navigation_tutorial")
    trade_run_index = User::ONBOARDING_STEPS.index("first_trade_run")
    
    assert_equal nav_index + 1, trade_run_index
  end

  test "first_trade_run comes before trade_routes" do
    trade_run_index = User::ONBOARDING_STEPS.index("first_trade_run")
    routes_index = User::ONBOARDING_STEPS.index("trade_routes")
    
    assert_equal trade_run_index + 1, routes_index
  end
end
