require "test_helper"

class BookmarksWarpTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @origin = systems(:cradle)
    @dest = systems(:mira_station)
    @ship = ships(:hauler)
    @ship.update_columns(current_system_id: @origin.id, fuel: 100.0, status: "docked",
                         location_x: @origin.x, location_y: @origin.y, location_z: @origin.z)
    sign_in_as(@user)

    # Create visit and bookmark
    SystemVisit.find_or_create_by!(user: @user, system: @dest) do |sv|
      sv.first_visited_at = Time.current
      sv.last_visited_at = Time.current
    end
    @bookmark = Bookmark.create!(user: @user, system: @dest)

    # Create warp gate connection
    WarpGate.create!(system_a: @origin, system_b: @dest, short_id: "wg-bw1")
  end

  teardown do
    WarpGate.where(short_id: "wg-bw1").delete_all
  end

  test "warp_route shows preview" do
    get warp_route_bookmark_path(@bookmark)
    assert_response :success
    assert_select "div", /Warp Route Preview/
  end

  test "warp_route with confirm executes warp" do
    post warp_route_bookmark_path(@bookmark, confirm: "true")
    assert_redirected_to bookmarks_path
    @ship.reload
    assert_equal @dest.id, @ship.current_system_id
  end

  test "warp_route shows error when no route" do
    WarpGate.where(short_id: "wg-bw1").delete_all
    get warp_route_bookmark_path(@bookmark)
    assert_redirected_to bookmarks_path
    assert_match /No warp route/i, flash[:alert]
  end
end
