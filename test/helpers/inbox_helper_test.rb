# frozen_string_literal: true

require "test_helper"

class InboxHelperTest < ActionView::TestCase
  include InboxHelper

  def setup
    @user = users(:one)
  end

  test "unread_count returns count of unread messages for user" do
    # user :one has 2 unread messages in fixtures
    assert_equal 2, unread_count(@user)
  end

  test "unread_count returns 0 when no unread messages" do
    # Mark all messages as read
    @user.messages.update_all(read_at: Time.current)
    assert_equal 0, unread_count(@user)
  end

  test "unread_count only counts messages for specified user" do
    # pilot user has 1 unread message, should not affect one's count
    pilot_user = users(:pilot)
    assert_equal 1, unread_count(pilot_user)
  end

  test "unread_badge returns badge HTML when count > 0" do
    badge = unread_badge(@user)
    assert_includes badge, "2"
    assert_includes badge, "unread-badge"
  end

  test "unread_badge includes Stimulus controller data attributes" do
    badge = unread_badge(@user)
    assert_includes badge, 'data-controller="unread-counter"'
    assert_includes badge, 'data-unread-counter-count-value="2"'
  end

  test "unread_badge returns nil when count is 0" do
    @user.messages.update_all(read_at: Time.current)
    assert_nil unread_badge(@user)
  end
end
