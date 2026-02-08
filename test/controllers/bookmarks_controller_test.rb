require "test_helper"

class BookmarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @system = systems(:cradle)
    sign_in_as(@user)
    SystemVisit.find_or_create_by!(user: @user, system: @system) do |sv|
      sv.first_visited_at = Time.current
      sv.last_visited_at = Time.current
    end
  end

  test "index lists bookmarks" do
    Bookmark.create!(user: @user, system: @system, label: "Home")
    get bookmarks_path
    assert_response :success
    assert_select "span", "The Cradle"
  end

  test "create bookmark for visited system" do
    assert_difference "Bookmark.count", 1 do
      post bookmarks_path, params: { system_id: @system.id, label: "Base" }
    end
  end

  test "create rejects unvisited system" do
    unvisited = systems(:alpha_centauri)
    assert_no_difference "Bookmark.count" do
      post bookmarks_path, params: { system_id: unvisited.id }
    end
  end

  test "create rejects duplicate bookmark" do
    Bookmark.create!(user: @user, system: @system)
    assert_no_difference "Bookmark.count" do
      post bookmarks_path, params: { system_id: @system.id }
    end
  end

  test "update bookmark label" do
    bookmark = Bookmark.create!(user: @user, system: @system, label: "Old")
    patch bookmark_path(bookmark), params: { label: "New" }
    assert_redirected_to bookmarks_path
    assert_equal "New", bookmark.reload.label
  end

  test "destroy bookmark" do
    bookmark = Bookmark.create!(user: @user, system: @system)
    assert_difference "Bookmark.count", -1 do
      delete bookmark_path(bookmark)
    end
    assert_redirected_to bookmarks_path
  end
end
