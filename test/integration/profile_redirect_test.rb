require "test_helper"

class ProfileRedirectTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(profile_completed_at: nil) # Ensure profile not completed
  end

  test "user without completed profile is redirected to edit profile" do
    sign_in_as(@user)
    
    # Try to access inbox (home)
    get root_path
    assert_redirected_to edit_profile_path
    follow_redirect!
    assert_select ".notice", /profile/i
  end

  test "user without completed profile can access profile pages" do
    sign_in_as(@user)
    
    # Should be able to access profile edit
    get edit_profile_path
    assert_response :success
    
    # Should be able to access profile show
    get profile_path
    assert_response :success
  end

  test "user without completed profile can sign out" do
    sign_in_as(@user)
    
    # Should be able to sign out
    delete sessions_path
    assert_redirected_to new_session_path
  end

  test "user with completed profile can access all pages" do
    @user.complete_profile!
    sign_in_as(@user)
    
    # Should be able to access inbox (home)
    get root_path
    assert_response :success
  end

  test "completing profile allows access to other pages" do
    sign_in_as(@user)
    
    # First, update profile
    patch profile_path, params: { user: { name: "Commander Test" } }
    assert_redirected_to profile_path
    
    # Now should be able to access home
    get root_path
    assert_response :success
  end

  test "unauthenticated users are not affected by profile redirect" do
    get new_session_path
    assert_response :success
  end
end
