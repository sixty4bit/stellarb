require "test_helper"

class BookmarkTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @system = systems(:cradle)
  end

  test "valid bookmark" do
    bookmark = Bookmark.new(user: @user, system: @system)
    assert bookmark.valid?
  end

  test "requires user" do
    bookmark = Bookmark.new(system: @system)
    assert_not bookmark.valid?
    assert_includes bookmark.errors[:user], "must exist"
  end

  test "requires system" do
    bookmark = Bookmark.new(user: @user)
    assert_not bookmark.valid?
    assert_includes bookmark.errors[:system], "must exist"
  end

  test "uniqueness of system scoped to user" do
    Bookmark.create!(user: @user, system: @system)
    duplicate = Bookmark.new(user: @user, system: @system)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:system_id], "has already been bookmarked"
  end

  test "different users can bookmark same system" do
    Bookmark.create!(user: @user, system: @system)
    other_user = users(:pilot)
    bookmark = Bookmark.new(user: other_user, system: @system)
    assert bookmark.valid?
  end

  test "label is optional" do
    bookmark = Bookmark.new(user: @user, system: @system, label: nil)
    assert bookmark.valid?
  end

  test "label can be set" do
    bookmark = Bookmark.create!(user: @user, system: @system, label: "Home Base")
    assert_equal "Home Base", bookmark.label
  end

  test "belongs to user" do
    bookmark = Bookmark.create!(user: @user, system: @system)
    assert_equal @user, bookmark.user
  end

  test "belongs to system" do
    bookmark = Bookmark.create!(user: @user, system: @system)
    assert_equal @system, bookmark.system
  end

  test "user has_many bookmarks" do
    bookmark = Bookmark.create!(user: @user, system: @system)
    assert_includes @user.bookmarks, bookmark
  end
end
