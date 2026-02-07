# frozen_string_literal: true

require "test_helper"

class PromotionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @worker = hired_recruits(:hired_engineer)
    sign_in_as(@user)
  end

  test "promote worker to assistant" do
    assert_equal "crew", @worker.role

    post promotions_path(worker_id: @worker.id)

    @worker.reload
    assert_equal "assistant", @worker.role
    assert_redirected_to worker_path(@worker)
    follow_redirect!
    assert_select "*", text: /promoted/i
  end

  test "cannot promote when assistant already exists" do
    @worker.update!(role: "assistant")

    other_worker = hired_recruits(:hired_navigator)
    post promotions_path(worker_id: other_worker.id)

    other_worker.reload
    assert_equal "crew", other_worker.role
    assert_redirected_to worker_path(other_worker)
    follow_redirect!
    assert_select "*", text: /already have an assistant/i
  end

  test "demote assistant to crew" do
    @worker.update!(role: "assistant")

    delete promotion_path(@worker)

    @worker.reload
    assert_equal "crew", @worker.role
    assert_redirected_to worker_path(@worker)
    follow_redirect!
    assert_select "*", text: /demoted/i
  end

  test "cannot demote non-assistant" do
    delete promotion_path(@worker)

    assert_redirected_to worker_path(@worker)
    follow_redirect!
    assert_select "*", text: /not an assistant/i
  end
end
