# frozen_string_literal: true

require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "message belongs to user" do
    user = users(:one)
    message = Message.new(
      user: user,
      title: "Test",
      body: "Test body",
      from: "System"
    )
    assert_equal user, message.user
  end

  test "message requires user, title, body, and from" do
    message = Message.new
    assert_not message.valid?
    assert_includes message.errors[:user], "must exist"
    assert_includes message.errors[:title], "can't be blank"
    assert_includes message.errors[:body], "can't be blank"
    assert_includes message.errors[:from], "can't be blank"
  end

  test "message defaults to unread" do
    user = users(:one)
    message = Message.create!(
      user: user,
      title: "Test",
      body: "Test body",
      from: "System"
    )
    assert_not message.read?
  end

  test "message defaults to not urgent" do
    user = users(:one)
    message = Message.create!(
      user: user,
      title: "Test",
      body: "Test body",
      from: "System"
    )
    assert_not message.urgent?
  end

  test "mark_read! marks message as read" do
    user = users(:one)
    message = Message.create!(
      user: user,
      title: "Test",
      body: "Test body",
      from: "System"
    )
    message.mark_read!
    assert message.read?
    assert_not_nil message.read_at
  end

  test "unread scope returns only unread messages" do
    user = users(:one)
    unread = Message.create!(user: user, title: "Unread", body: "Body", from: "System")
    read = Message.create!(user: user, title: "Read", body: "Body", from: "System", read_at: Time.current)

    assert_includes Message.unread, unread
    assert_not_includes Message.unread, read
  end

  test "urgent scope returns only urgent messages" do
    user = users(:one)
    urgent = Message.create!(user: user, title: "Urgent!", body: "Body", from: "System", urgent: true)
    normal = Message.create!(user: user, title: "Normal", body: "Body", from: "System", urgent: false)

    assert_includes Message.urgent, urgent
    assert_not_includes Message.urgent, normal
  end
end
