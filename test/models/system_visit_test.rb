# frozen_string_literal: true

require "test_helper"

class SystemVisitTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Explorer", email: "explorer@test.com")
    @system = System.create!(x: 0, y: 0, z: 0, name: "The Cradle")
  end

  # ===========================================
  # Visit Recording Tests
  # ===========================================

  test "record_visit creates new visit for first-time visitor" do
    assert_difference "SystemVisit.count", 1 do
      visit = SystemVisit.record_visit(@user, @system)

      assert_equal @user, visit.user
      assert_equal @system, visit.system
      assert_equal 1, visit.visit_count
      assert visit.first_visited_at.present?
      assert visit.last_visited_at.present?
    end
  end

  test "record_visit increments count for returning visitor" do
    # First visit
    first_visit = SystemVisit.record_visit(@user, @system)
    first_visited_at = first_visit.first_visited_at

    # Second visit
    travel 1.hour do
      visit = SystemVisit.record_visit(@user, @system)

      assert_equal 2, visit.visit_count
      # First visited should not change
      assert_equal first_visited_at.to_i, visit.first_visited_at.to_i
      # Last visited should update
      assert visit.last_visited_at > first_visited_at
    end
  end

  test "record_visit does not create duplicate visits" do
    SystemVisit.record_visit(@user, @system)

    assert_no_difference "SystemVisit.count" do
      SystemVisit.record_visit(@user, @system)
    end
  end

  # ===========================================
  # Guest Book Tests (System's Visitors)
  # ===========================================

  test "system has many visitors through system_visits" do
    user2 = User.create!(name: "Second Explorer", email: "second@test.com")

    SystemVisit.record_visit(@user, @system)
    SystemVisit.record_visit(user2, @system)

    assert_includes @system.visitors, @user
    assert_includes @system.visitors, user2
    assert_equal 2, @system.visitors.count
  end

  test "system guest_book returns visitors with visit info ordered by first visit" do
    user2 = User.create!(name: "Second Explorer", email: "second@test.com")

    travel_to 2.days.ago do
      SystemVisit.record_visit(@user, @system)
    end

    travel_to 1.day.ago do
      SystemVisit.record_visit(user2, @system)
    end

    guest_book = @system.guest_book
    assert_equal 2, guest_book.length
    # First visitor should be first in list (ordered by first_visited_at)
    assert_equal @user.id, guest_book.first.user_id
  end

  test "system recent_visitors returns most recent visitors first" do
    user2 = User.create!(name: "Second Explorer", email: "second@test.com")

    travel_to 2.days.ago do
      SystemVisit.record_visit(@user, @system)
    end

    travel_to 1.day.ago do
      SystemVisit.record_visit(user2, @system)
    end

    recent = @system.recent_visitors(limit: 10)
    # Most recent visitor should be first
    assert_equal user2.id, recent.first.user_id
  end

  # ===========================================
  # User's Visited Systems Tests
  # ===========================================

  test "user has many visited_systems through system_visits" do
    system2 = System.create!(x: 3, y: 0, z: 0, name: "Second System")

    SystemVisit.record_visit(@user, @system)
    SystemVisit.record_visit(@user, system2)

    assert_includes @user.visited_systems, @system
    assert_includes @user.visited_systems, system2
    assert_equal 2, @user.visited_systems.count
  end

  test "user travel_log returns systems with visit info ordered by most recent" do
    system2 = System.create!(x: 3, y: 0, z: 0, name: "Second System")

    travel_to 2.days.ago do
      SystemVisit.record_visit(@user, @system)
    end

    travel_to 1.day.ago do
      SystemVisit.record_visit(@user, system2)
    end

    log = @user.travel_log
    assert_equal 2, log.length
    # Most recent should be first
    assert_equal system2.id, log.first.system_id
  end

  # ===========================================
  # Validation Tests
  # ===========================================

  test "validates presence of required fields" do
    visit = SystemVisit.new

    assert_not visit.valid?
    assert_includes visit.errors[:first_visited_at], "can't be blank"
    assert_includes visit.errors[:last_visited_at], "can't be blank"
  end

  test "validates visit_count is positive" do
    visit = SystemVisit.new(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 0
    )

    assert_not visit.valid?
    assert_includes visit.errors[:visit_count], "must be greater than 0"
  end

  test "enforces unique user-system combination" do
    SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1
    )

    duplicate = SystemVisit.new(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1
    )

    assert_not duplicate.valid?
  end
end
