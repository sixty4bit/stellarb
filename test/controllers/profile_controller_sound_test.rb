require "test_helper"

class ProfileControllerSoundTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "sound preference is included in profile params" do
    patch profile_url, params: { user: { name: "Updated Name", sound_enabled: "0" } }
    @user.reload
    assert_not @user.sound_enabled?
  end

  test "sound preference can be enabled" do
    @user.update!(sound_enabled: false)
    patch profile_url, params: { user: { name: @user.name, sound_enabled: "1" } }
    @user.reload
    assert @user.sound_enabled?
  end

  test "turbo stream response includes sound preference update" do
    patch profile_url, params: { user: { name: @user.name, sound_enabled: "0" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    @user.reload
    assert_not @user.sound_enabled?
  end
end
