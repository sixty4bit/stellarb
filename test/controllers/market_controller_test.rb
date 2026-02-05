# frozen_string_literal: true

require "test_helper"

class MarketControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @system = systems(:cradle)
    sign_in_as(@user)
    
    # Ensure user has visited the system
    @user.system_visits.find_or_create_by!(system: @system) do |visit|
      visit.first_visited_at = 1.day.ago
      visit.last_visited_at = Time.current
      visit.visit_count = 1
    end
  end

  # Screen 18: Market
  test "index renders market page" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "h1", text: /Market/
  end

  test "index shows system name" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "*", text: /#{@system.name}/
  end

  test "index shows buy prices" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "*", text: /Buy/i
  end

  test "index shows sell prices" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "*", text: /Sell/i
  end

  test "index shows trend indicators" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "*", text: /Trend/i
  end

  test "index shows player credits" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "*", text: /Credits/i
  end

  test "index has buy action" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "a, button", text: /Buy/i
  end

  test "index has sell action" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "a, button", text: /Sell/i
  end

  test "index has back to system link" do
    get system_market_index_path(@system)
    assert_response :success
    assert_select "a[href='#{system_path(@system)}']"
  end
end
