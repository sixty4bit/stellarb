require "test_helper"

class UserProfileTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "user has profile_completed_at attribute" do
    assert_respond_to @user, :profile_completed_at
    assert_respond_to @user, :profile_completed_at=
  end

  test "profile_completed? returns false when profile_completed_at is nil" do
    @user.profile_completed_at = nil
    assert_not @user.profile_completed?
  end

  test "profile_completed? returns true when profile_completed_at is set" do
    @user.profile_completed_at = Time.current
    assert @user.profile_completed?
  end

  test "complete_profile! sets profile_completed_at" do
    assert_nil @user.profile_completed_at
    @user.complete_profile!
    assert_not_nil @user.profile_completed_at
    assert @user.profile_completed?
  end

  test "complete_profile! does not change timestamp if already completed" do
    original_time = 1.day.ago
    @user.update!(profile_completed_at: original_time)
    @user.complete_profile!
    assert_equal original_time.to_i, @user.profile_completed_at.to_i
  end
end
