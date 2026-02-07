# frozen_string_literal: true

require "test_helper"

class WorkerPromotionViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @worker = hired_recruits(:hired_engineer)
    sign_in_as(@user)
  end

  test "shows promote button when no assistant exists" do
    get worker_path(@worker)
    assert_response :success
    assert_select "input[value*='Promote']", count: 0 # button_to renders as input
    assert_select "button", text: /Promote to Assistant/
  end

  test "shows assistant badge when worker is assistant" do
    @worker.update!(role: "assistant")
    get worker_path(@worker)
    assert_response :success
    assert_select "*", text: /Assistant/
    assert_select "button", text: /Demote to Crew/
  end

  test "shows cooldown info for assistant on cooldown" do
    @worker.update!(role: "assistant", assistant_cooldown_until: 3.hours.from_now)
    get worker_path(@worker)
    assert_response :success
    assert_select "*", text: /cooldown/i
  end
end
