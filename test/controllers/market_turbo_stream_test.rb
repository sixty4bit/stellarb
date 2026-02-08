# frozen_string_literal: true

require "test_helper"

class MarketTurboStreamTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @user.update!(profile_completed_at: Time.current, credits: 10_000)
    sign_in_as(@user)
  end

  test "credits partial renders with turbo-replaceable id" do
    get root_path
    assert_response :success
    assert_select "#user_credits", text: /Credits/
  end

  test "flash_messages container exists in layout" do
    get root_path
    assert_response :success
    assert_select "#flash_messages"
  end

  test "credits partial shows current credit amount" do
    get root_path
    assert_response :success
    assert_select "#user_credits", text: /10,000/
  end
end
