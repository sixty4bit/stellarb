# frozen_string_literal: true

require "test_helper"

class WelcomeMessageTest < ActiveSupport::TestCase
  test "creating a user creates welcome messages" do
    user = User.create!(
      email: "newpilot@example.com",
      name: "New Pilot"
    )

    assert_equal 2, user.messages.count
  end

  test "welcome message from Colonial Authority is created" do
    user = User.create!(
      email: "colonist@example.com",
      name: "Colonist"
    )

    welcome = user.messages.find_by(from: "Colonial Authority")
    assert_not_nil welcome
    assert_equal "Welcome to StellArb!", welcome.title
    assert_includes welcome.body, "Colonial Expansion Program"
    assert_not welcome.urgent?
    assert_equal "system", welcome.category
  end

  test "tutorial quest message from System Guide is created" do
    user = User.create!(
      email: "recruit@example.com",
      name: "Recruit"
    )

    tutorial = user.messages.find_by(from: "System Guide")
    assert_not_nil tutorial
    assert_equal "Tutorial Quest Available", tutorial.title
    assert_includes tutorial.body, "PRIORITY NOTIFICATION"
    assert tutorial.urgent?
    assert_equal "quest", tutorial.category
  end

  test "welcome messages are unread by default" do
    user = User.create!(
      email: "fresh@example.com",
      name: "Fresh Start"
    )

    user.messages.each do |message|
      assert message.unread?, "Message '#{message.title}' should be unread"
    end
  end

  test "welcome messages have unique UUIDs" do
    user = User.create!(
      email: "unique@example.com",
      name: "Unique User"
    )

    uuids = user.messages.pluck(:uuid)
    assert_equal uuids.uniq.length, uuids.length
    uuids.each { |uuid| assert_not_nil uuid }
  end
end
