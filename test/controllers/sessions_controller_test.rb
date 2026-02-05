# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get new_session_path
    assert_response :success
    assert_select "input[type=email]"
    assert_select "input[type=submit]"
  end

  test "login page shows terminal-style header" do
    get new_session_path
    assert_response :success
    # ASCII art header present in a pre tag
    assert_select "pre.text-orange-500"
    # Terminal version tag
    assert_match /Stellar Arbitrage Trading System/, response.body
  end

  test "login page shows CLI-style form elements" do
    get new_session_path
    assert_response :success
    # Terminal prompt symbols
    assert_match /EMAIL_ADDRESS/, response.body
    assert_match /TRANSMIT ACCESS REQUEST/, response.body
  end

  test "should create session with valid email" do
    email = "newpilot@example.com"

    assert_difference -> { User.count }, 1 do
      post sessions_path, params: { user: { email: email } }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    user = User.find_by(email: email)
    assert_not_nil user
    assert_equal session[:user_id], user.id
  end

  test "should sign in existing user" do
    user = users(:one)

    assert_no_difference -> { User.count } do
      post sessions_path, params: { user: { email: user.email } }
    end

    assert_redirected_to root_path
    assert_equal session[:user_id], user.id
  end

  test "should destroy session" do
    user = users(:one)
    sign_in_as(user)

    delete sessions_path

    assert_redirected_to new_session_path
    assert_nil session[:user_id]
  end
end
