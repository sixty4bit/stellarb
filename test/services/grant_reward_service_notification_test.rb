# frozen_string_literal: true

require "test_helper"

class GrantRewardServiceNotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "send_notification! creates congratulations message for user" do
    service = GrantRewardService.new(@user)
    service.send_notification!

    message = @user.messages.last
    assert_not_nil message
    assert_includes message.title.downcase, "grant"
  end

  test "notification is from Colonial Authority" do
    service = GrantRewardService.new(@user)
    service.send_notification!

    message = @user.messages.last
    assert_equal "Colonial Authority", message.from
  end

  test "notification mentions the grant amount" do
    service = GrantRewardService.new(@user)
    service.send_notification!

    message = @user.messages.last
    assert_includes message.body, "10,000"
  end

  test "notification is marked as urgent" do
    service = GrantRewardService.new(@user)
    service.send_notification!

    message = @user.messages.last
    assert message.urgent?
  end

  test "notification mentions Phase 2" do
    service = GrantRewardService.new(@user)
    service.send_notification!

    message = @user.messages.last
    assert_includes message.body.downcase, "phase 2"
  end

  test "notification has actionable context about purchasing ship" do
    service = GrantRewardService.new(@user)
    service.send_notification!

    message = @user.messages.last
    assert_includes message.body.downcase, "ship"
  end
end
