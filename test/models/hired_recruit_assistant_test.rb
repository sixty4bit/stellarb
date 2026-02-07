require "test_helper"

class HiredRecruitAssistantTest < ActiveSupport::TestCase
  setup do
    @user = users(:pilot)
    @ship = ships(:hauler)
    @recruit1 = HiredRecruit.create!(race: "vex", npc_class: "engineer", skill: 50, chaos_factor: 10)
    @recruit2 = HiredRecruit.create!(race: "solari", npc_class: "navigator", skill: 60, chaos_factor: 20)

    @hiring1 = Hiring.create!(user: @user, hired_recruit: @recruit1, status: :active, wage: 100, hired_at: Time.current, assignable: @ship)
    @hiring2 = Hiring.create!(user: @user, hired_recruit: @recruit2, status: :active, wage: 200, hired_at: Time.current, assignable: @ship)
  end

  # --- Constants ---

  test "ASSISTANT_COOLDOWN is 4 hours" do
    assert_equal 4.hours, HiredRecruit::ASSISTANT_COOLDOWN
  end

  # --- Scopes ---

  test ".assistants returns only assistant role" do
    assert_empty HiredRecruit.assistants

    @recruit1.promote_to_assistant!(@user)
    assert_includes HiredRecruit.assistants, @recruit1
    assert_not_includes HiredRecruit.assistants, @recruit2
  end

  # --- promote_to_assistant! ---

  test "promote_to_assistant! sets role to assistant" do
    @recruit1.promote_to_assistant!(@user)
    assert_equal "assistant", @recruit1.reload.role
  end

  test "promote_to_assistant! sets cooldown" do
    freeze_time do
      @recruit1.promote_to_assistant!(@user)
      assert_equal 4.hours.from_now, @recruit1.reload.assistant_cooldown_until
    end
  end

  test "promote_to_assistant! fails if user already has an assistant" do
    @recruit1.promote_to_assistant!(@user)

    assert_raises(ActiveRecord::RecordInvalid) do
      @recruit2.promote_to_assistant!(@user)
    end
  end

  test "promote_to_assistant! works for different users independently" do
    other_user = users(:one)
    other_ship = ships(:scout)
    recruit3 = HiredRecruit.create!(race: "krog", npc_class: "engineer", skill: 40, chaos_factor: 5)
    Hiring.create!(user: other_user, hired_recruit: recruit3, status: :active, wage: 200, hired_at: Time.current, assignable: other_ship)

    @recruit1.promote_to_assistant!(@user)
    recruit3.promote_to_assistant!(other_user)

    assert_equal "assistant", @recruit1.reload.role
    assert_equal "assistant", recruit3.reload.role
  end

  # --- demote_to_crew! ---

  test "demote_to_crew! sets role back to crew" do
    @recruit1.promote_to_assistant!(@user)
    @recruit1.demote_to_crew!

    assert_equal "crew", @recruit1.reload.role
  end

  # --- User#assistant ---

  test "user#assistant returns current assistant" do
    assert_nil @user.assistant

    @recruit1.promote_to_assistant!(@user)
    assert_equal @recruit1, @user.assistant
  end

  test "user#assistant returns nil after demotion" do
    @recruit1.promote_to_assistant!(@user)
    @recruit1.demote_to_crew!
    assert_nil @user.assistant
  end

  # --- Cooldown ---

  test "on_cooldown? returns true during cooldown" do
    freeze_time do
      @recruit1.promote_to_assistant!(@user)
      assert @recruit1.on_cooldown?
    end
  end

  test "on_cooldown? returns false after cooldown expires" do
    @recruit1.promote_to_assistant!(@user)
    travel 5.hours
    assert_not @recruit1.on_cooldown?
  end

  test "on_cooldown? returns false when no cooldown set" do
    assert_not @recruit1.on_cooldown?
  end

  test "cooldown_remaining returns remaining duration" do
    freeze_time do
      @recruit1.promote_to_assistant!(@user)
      travel 1.hour
      assert_in_delta 3.hours.to_i, @recruit1.cooldown_remaining.to_i, 1
    end
  end

  test "cooldown_remaining returns 0 when expired" do
    @recruit1.promote_to_assistant!(@user)
    travel 5.hours
    assert_equal 0, @recruit1.cooldown_remaining
  end

  # --- Validation: only one assistant per user ---

  test "validation prevents two assistants for same user" do
    @recruit1.update!(role: "assistant")
    @recruit2.role = "assistant"
    assert_not @recruit2.valid?
    assert_includes @recruit2.errors[:role], "user can only have one assistant"
  end
end
