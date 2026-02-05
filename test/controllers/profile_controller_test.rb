require "test_helper"

class ProfileControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  def sign_out
    delete sessions_path
  end

  # =========================================
  # SHOW
  # =========================================

  test "show renders profile page" do
    get profile_path
    assert_response :success
    assert_select "h1", /profile/i
  end

  test "show displays current user name" do
    get profile_path
    assert_response :success
    assert_select "input[value='#{@user.name}']"
  end

  test "show requires authentication" do
    sign_out
    get profile_path
    assert_redirected_to new_session_path
  end

  # =========================================
  # EDIT
  # =========================================

  test "edit renders edit form" do
    get edit_profile_path
    assert_response :success
    assert_select "form[action='#{profile_path}']"
  end

  # =========================================
  # UPDATE
  # =========================================

  test "update changes user name" do
    patch profile_path, params: { user: { name: "New Name" } }
    @user.reload
    assert_equal "New Name", @user.name
  end

  test "update redirects to profile on success" do
    patch profile_path, params: { user: { name: "New Name" } }
    assert_redirected_to profile_path
    follow_redirect!
    assert_select ".notice", /updated/i
  end

  test "update marks profile as completed if not already" do
    assert_nil @user.profile_completed_at
    patch profile_path, params: { user: { name: "New Name" } }
    @user.reload
    assert_not_nil @user.profile_completed_at
  end

  test "update with blank name shows error" do
    patch profile_path, params: { user: { name: "" } }
    assert_response :unprocessable_entity
    assert_select ".error", /name/i
  end

  test "update requires authentication" do
    sign_out
    patch profile_path, params: { user: { name: "Hacker" } }
    assert_redirected_to new_session_path
  end
end
