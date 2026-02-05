# frozen_string_literal: true

require "test_helper"

class WorkersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @hired_recruit = hired_recruits(:hired_engineer)
    sign_in_as(@user)
  end

  # Screen 14: Workers List
  test "index renders workers list" do
    get workers_path
    assert_response :success
    assert_select "h1", text: /Workers/
  end

  test "index shows user workers" do
    get workers_path
    assert_response :success
    # Should show the hired engineer
    assert_select "*", text: /engineer/i
  end

  test "index displays worker class" do
    get workers_path
    assert_response :success
    assert_select "*", text: /Engineer/i
  end

  test "index has link to recruiter" do
    get workers_path
    assert_response :success
    assert_select "a[href='#{recruiter_workers_path}']"
  end

  test "index shows assigned status" do
    get workers_path
    assert_response :success
    # Should show worker assignment status
    assert_select "*", text: /ACTIVE/i
  end

  # Screen 15: Recruiter
  test "recruiter renders recruiter screen" do
    get recruiter_workers_path
    assert_response :success
    assert_select "h1", text: /Recruiter/i
  end

  test "recruiter shows available recruits" do
    get recruiter_workers_path
    assert_response :success
    # Should show available recruits for this level tier
    assert_select "*", text: /engineer/i
  end

  test "recruiter displays skill levels" do
    get recruiter_workers_path
    assert_response :success
    assert_select "*", text: /Skill/i
  end

  test "recruiter shows employment history hint" do
    get recruiter_workers_path
    assert_response :success
    # Resume/history should be viewable
    assert_select "*", text: /history/i
  end

  test "recruiter has hire action" do
    get recruiter_workers_path
    assert_response :success
    assert_select "a, button, form", text: /Hire/i
  end

  # Screen 16: Worker Detail
  test "show renders worker detail" do
    get worker_path(@hired_recruit)
    assert_response :success
    assert_select "*", text: /Engineer/i
  end

  test "show displays employment history" do
    get worker_path(@hired_recruit)
    assert_response :success
    assert_select "*", text: /Employment History/i
  end

  test "show displays skill level" do
    get worker_path(@hired_recruit)
    assert_response :success
    assert_select "*", text: /Skill/i
  end

  test "show displays traits/quirks" do
    get worker_path(@hired_recruit)
    assert_response :success
    assert_select "*", text: /Traits/i
  end

  test "show has back to workers link" do
    get worker_path(@hired_recruit)
    assert_response :success
    assert_select "a[href='#{workers_path}']"
  end

  test "show displays wage information" do
    get worker_path(@hired_recruit)
    assert_response :success
    assert_select "*", text: /Wage/i
  end
end
