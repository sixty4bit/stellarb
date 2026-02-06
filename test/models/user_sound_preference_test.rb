require "test_helper"

class UserSoundPreferenceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "user has sound_enabled attribute" do
    assert_respond_to @user, :sound_enabled
    assert_respond_to @user, :sound_enabled=
    assert_respond_to @user, :sound_enabled?
  end

  test "sound_enabled defaults to true" do
    new_user = User.new(email: "test@example.com", name: "Test User", short_id: "u-test123")
    assert new_user.sound_enabled?, "sound_enabled should default to true"
  end

  test "sound_enabled can be disabled" do
    @user.update!(sound_enabled: false)
    assert_not @user.sound_enabled?
  end

  test "sound_enabled can be toggled" do
    @user.update!(sound_enabled: true)
    assert @user.sound_enabled?

    @user.update!(sound_enabled: false)
    assert_not @user.sound_enabled?

    @user.update!(sound_enabled: true)
    assert @user.sound_enabled?
  end
end
