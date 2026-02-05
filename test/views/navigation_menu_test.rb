require "test_helper"

class NavigationMenuTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "navigation menu shows user name as link to profile" do
    get root_path
    assert_response :success
    
    # User name should be a link to profile
    assert_select "a[href='#{profile_path}'] h1", @user.name
  end

  test "navigation menu shows user credits" do
    get root_path
    assert_response :success
    
    # Should display credits
    assert_match "Credits:", response.body
    assert_match "1,000", response.body  # Formatted credits from fixture
  end

  test "clicking user name navigates to profile" do
    get root_path
    assert_response :success
    
    # Find the profile link and verify it points to profile_path
    assert_select "a[href='#{profile_path}']" do |links|
      # There should be at least one link to profile
      assert links.any?
    end
  end
end
