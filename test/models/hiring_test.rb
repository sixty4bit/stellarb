# frozen_string_literal: true

require "test_helper"

class HiringTest < ActiveSupport::TestCase
  fixtures []

  setup do
    @user = User.create!(email: "test@example.com", name: "Test User", level_tier: 1)
    @recruit = Recruit.generate!(level_tier: 1)
    @ship = create_test_ship(@user)
  end

  # =====================
  # Created via hire!
  # =====================

  test "hire! creates Hiring join record" do
    hiring = @recruit.hire!(@user, @ship)

    assert hiring.persisted?
    assert_kind_of Hiring, hiring
  end

  test "Hiring links user to hired_recruit" do
    hiring = @recruit.hire!(@user, @ship)

    assert_equal @user, hiring.user
    assert_kind_of HiredRecruit, hiring.hired_recruit
  end

  test "Hiring sets assignable to provided asset" do
    hiring = @recruit.hire!(@user, @ship)

    assert_equal @ship, hiring.assignable
  end

  test "Hiring defaults to active status" do
    hiring = @recruit.hire!(@user, @ship)

    assert_equal "active", hiring.status
    assert hiring.active_status?
  end

  test "Hiring sets hired_at timestamp" do
    now = Time.current
    hiring = @recruit.hire!(@user, @ship)

    assert_not_nil hiring.hired_at
    assert_in_delta now.to_i, hiring.hired_at.to_i, 2
  end

  test "Hiring calculates wage from hired_recruit" do
    hiring = @recruit.hire!(@user, @ship)

    expected_wage = hiring.hired_recruit.calculate_wage
    assert_equal expected_wage, hiring.wage
    assert hiring.wage > 0
  end

  # =====================
  # Validations
  # =====================

  test "validates presence of status" do
    hiring = build_hiring(status: nil)
    assert_not hiring.valid?
    assert_includes hiring.errors[:status], "can't be blank"
  end

  test "wage defaults from hired_recruit on create" do
    # Wage is auto-calculated if not provided
    hired_recruit = HiredRecruit.create_from_recruit!(@recruit, @user)
    hiring = Hiring.new(
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: "active",
      hired_at: Time.current
    )

    assert_nil hiring.wage
    hiring.valid? # triggers before_validation callback
    assert_equal hired_recruit.calculate_wage, hiring.wage
  end

  test "validates wage is greater than 0" do
    hired_recruit = HiredRecruit.create_from_recruit!(@recruit, @user)
    hiring = Hiring.new(
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: "active",
      hired_at: Time.current,
      wage: 0
    )
    assert_not hiring.valid?
    assert_includes hiring.errors[:wage], "must be greater than 0"
  end

  test "hired_at defaults to current time on create" do
    # hired_at is auto-set if not provided
    hired_recruit = HiredRecruit.create_from_recruit!(@recruit, @user)
    hiring = Hiring.new(
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: "active",
      wage: 100
    )

    assert_nil hiring.hired_at
    hiring.valid? # triggers before_validation callback
    assert_not_nil hiring.hired_at
    assert_in_delta Time.current.to_i, hiring.hired_at.to_i, 2
  end

  test "validates uniqueness of active hiring per user per recruit" do
    hired_recruit = HiredRecruit.create_from_recruit!(@recruit, @user)

    # First active hiring succeeds
    Hiring.create!(
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: "active",
      hired_at: Time.current,
      wage: 100
    )

    # Second active hiring for same user/recruit fails
    duplicate = Hiring.new(
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: "active",
      hired_at: Time.current,
      wage: 100
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:hired_recruit_id], "is already actively employed by this user"
  end

  # =====================
  # Scopes
  # =====================

  test "active scope returns only active hirings" do
    hiring1 = @recruit.hire!(@user, @ship)

    recruit2 = Recruit.generate!(level_tier: 1)
    ship2 = create_test_ship(@user)
    hiring2 = recruit2.hire!(@user, ship2)
    hiring2.terminate!("fired")

    assert_includes Hiring.active, hiring1
    assert_not_includes Hiring.active, hiring2
  end

  test "terminated scope returns non-active hirings" do
    hiring1 = @recruit.hire!(@user, @ship)

    recruit2 = Recruit.generate!(level_tier: 1)
    ship2 = create_test_ship(@user)
    hiring2 = recruit2.hire!(@user, ship2)
    hiring2.terminate!("retired")

    assert_not_includes Hiring.terminated, hiring1
    assert_includes Hiring.terminated, hiring2
  end

  # NOTE: assignable is NOT NULL in schema, so unassigned scope would
  # only apply to legacy data. Hirings must always have an assignment.
  test "hirings require assignable" do
    hiring = @recruit.hire!(@user, @ship)
    assert_not_nil hiring.assignable
  end

  # =====================
  # Status Methods
  # =====================

  test "terminate! changes status and sets terminated_at" do
    hiring = @recruit.hire!(@user, @ship)

    hiring.terminate!("fired")

    assert_equal "fired", hiring.status
    assert hiring.fired_status?
    assert_not_nil hiring.terminated_at
    # NOTE: assignable is NOT NULL in schema, so it remains set
    assert_not_nil hiring.assignable
  end

  test "terminate! can be called with different reasons" do
    %w[fired deceased retired striking].each do |reason|
      recruit = Recruit.generate!(level_tier: 1)
      ship = create_test_ship(@user)
      hiring = recruit.hire!(@user, ship)

      hiring.terminate!(reason)

      assert_equal reason, hiring.status
    end
  end

  # =====================
  # Assignment Methods
  # =====================

  test "assign_to! changes assignable" do
    hiring = @recruit.hire!(@user, @ship)
    new_ship = create_test_ship(@user)

    hiring.assign_to!(new_ship)

    assert_equal new_ship, hiring.assignable
  end

  # NOTE: unassign! is not supported - schema requires assignable.
  # Use assign_to! to reassign, or terminate! to end employment.
  test "assign_to! can reassign to different asset" do
    hiring = @recruit.hire!(@user, @ship)
    new_ship = create_test_ship(@user)

    hiring.assign_to!(new_ship)
    hiring.reload

    assert_equal new_ship, hiring.assignable
    assert_equal "active", hiring.status
  end

  private

  def create_test_ship(user)
    Ship.create!(
      user: user,
      name: "Test Ship #{SecureRandom.hex(3)}",
      race: "vex",
      hull_size: "scout",
      variant_idx: 0,
      location_x: 0,
      location_y: 0,
      location_z: 0
    )
  end

  def build_hiring(overrides = {})
    hired_recruit = overrides[:hired_recruit] || HiredRecruit.create_from_recruit!(@recruit, @user)

    defaults = {
      user: @user,
      hired_recruit: hired_recruit,
      assignable: @ship,
      status: "active",
      hired_at: Time.current,
      wage: 100
    }
    Hiring.new(defaults.merge(overrides))
  end
end
