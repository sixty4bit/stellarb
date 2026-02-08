require "test_helper"

class BookmarksViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @system = systems(:cradle)
    sign_in_as(@user)
  end

  test "bookmark index renders empty state" do
    get bookmarks_path
    assert_response :success
    assert_select "p", /No bookmarks yet/
  end

  test "bookmark index shows bookmarks with system names" do
    SystemVisit.find_or_create_by!(user: @user, system: @system) do |sv|
      sv.first_visited_at = Time.current
      sv.last_visited_at = Time.current
    end
    Bookmark.create!(user: @user, system: @system, label: "Home Base")
    get bookmarks_path
    assert_response :success
    assert_select "a", "The Cradle"
  end
end
