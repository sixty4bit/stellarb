require "test_helper"

class SoundHelperTest < ActionView::TestCase
  include SoundHelper

  setup do
    @user = users(:one)
  end

  test "sound_enabled? returns true when no current_user" do
    # No current_user defined
    assert sound_enabled?
  end

  test "sound_enabled? returns true when user has sound enabled" do
    @user.update!(sound_enabled: true)
    define_singleton_method(:current_user) { @user }
    assert sound_enabled?
  end

  test "sound_enabled? returns false when user has sound disabled" do
    @user.update!(sound_enabled: false)
    define_singleton_method(:current_user) { @user }
    assert_not sound_enabled?
  end

  test "sound_tag returns element when sound enabled" do
    @user.update!(sound_enabled: true)
    define_singleton_method(:current_user) { @user }
    
    result = sound_tag("/sounds/test.mp3")
    assert_not_nil result
    assert_match "audio", result.to_s
  end

  test "sound_tag returns nil when sound disabled" do
    @user.update!(sound_enabled: false)
    define_singleton_method(:current_user) { @user }
    
    result = sound_tag("/sounds/test.mp3")
    assert_nil result
  end
end
