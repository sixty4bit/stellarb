# frozen_string_literal: true

require "test_helper"

class MessageBroadcastTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "message has broadcast_unread_badge method" do
    message = Message.new(
      user: @user,
      title: "Test",
      body: "Test body",
      from: "System"
    )

    assert message.respond_to?(:broadcast_unread_badge),
      "Message should respond to broadcast_unread_badge"
  end

  test "message has after_commit callback for broadcasting" do
    callbacks = Message._commit_callbacks.select { |c| c.filter == :broadcast_unread_badge }
    assert callbacks.any?, "Message should have after_commit callback for broadcast_unread_badge"
  end

  test "broadcast_unread_badge_target returns correct stream name" do
    message = messages(:unread_message_one)
    expected_target = "inbox_unread_badge_user_#{@user.id}"
    assert_equal expected_target, message.broadcast_unread_badge_target
  end
end
