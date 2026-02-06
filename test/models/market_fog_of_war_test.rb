# frozen_string_literal: true

require "test_helper"

class MarketFogOfWarTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Trader", email: "trader@test.com")
    # Use The Cradle (0,0,0) which has fixed base_prices
    @system = System.cradle
  end

  # ===========================================
  # SystemVisit Price Snapshot Tests
  # ===========================================

  test "record_visit snapshots current prices" do
    visit = SystemVisit.record_visit(@user, @system)

    assert visit.price_snapshot.present?
    assert_kind_of Hash, visit.price_snapshot
    # System should have base prices from properties
    assert visit.price_snapshot.any?, "Snapshot should contain prices"
  end

  test "record_visit updates snapshot on subsequent visits" do
    # First visit
    visit = SystemVisit.record_visit(@user, @system)
    first_snapshot = visit.price_snapshot.dup
    first_iron_price = first_snapshot["iron"]

    # Manually change a price delta (increase iron price by 50)
    PriceDelta.apply_delta(@system, "iron", 50)

    # Second visit should update snapshot
    travel 1.hour do
      visit = SystemVisit.record_visit(@user, @system)
    end

    # Snapshot should reflect the new price
    assert visit.price_snapshot.present?
    # The iron price should be higher now
    assert_equal first_iron_price + 50, visit.price_snapshot["iron"],
      "Snapshot should reflect price delta"
  end

  test "snapshot_prices! captures current system prices" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1
    )

    visit.snapshot_prices!
    
    assert_equal @system.current_prices, visit.price_snapshot
  end

  # ===========================================
  # Staleness Calculation Tests
  # ===========================================

  test "staleness returns duration since snapshot" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 2.hours.ago,
      last_visited_at: 2.hours.ago,
      visit_count: 1
    )

    assert_in_delta 2.hours.to_i, visit.staleness.to_i, 5
  end

  test "staleness_label shows just now for recent snapshots" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 30.seconds.ago,
      last_visited_at: 30.seconds.ago,
      visit_count: 1
    )

    assert_equal "just now", visit.staleness_label
  end

  test "staleness_label shows minutes for short intervals" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 15.minutes.ago,
      last_visited_at: 15.minutes.ago,
      visit_count: 1
    )

    assert_match(/15 minutes ago/, visit.staleness_label)
  end

  test "staleness_label shows hours for medium intervals" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 3.hours.ago,
      last_visited_at: 3.hours.ago,
      visit_count: 1
    )

    assert_match(/3 hours ago/, visit.staleness_label)
  end

  test "staleness_label shows days for long intervals" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 2.days.ago,
      last_visited_at: 2.days.ago,
      visit_count: 1
    )

    assert_match(/2 days ago/, visit.staleness_label)
  end

  test "staleness_label handles singular form correctly" do
    visit_1min = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 1.minute.ago,
      last_visited_at: 1.minute.ago,
      visit_count: 1
    )

    assert_match(/1 minute ago/, visit_1min.staleness_label)
    assert_no_match(/1 minutes ago/, visit_1min.staleness_label)
  end

  test "stale? returns true for old snapshots" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: 2.hours.ago,
      last_visited_at: 2.hours.ago,
      visit_count: 1
    )

    assert visit.stale?(threshold: 1.hour)
    assert_not visit.stale?(threshold: 3.hours)
  end

  # ===========================================
  # Remembered Prices Tests
  # ===========================================

  test "remembered_prices returns snapshot data" do
    visit = SystemVisit.record_visit(@user, @system)

    remembered = visit.remembered_prices
    
    assert_kind_of Hash, remembered
    assert remembered.any?
  end

  test "remembered_prices returns empty hash if no snapshot" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1,
      price_snapshot: nil
    )

    assert_equal({}, visit.remembered_prices)
  end

  test "has_price_snapshot? returns true when snapshot exists" do
    visit = SystemVisit.record_visit(@user, @system)

    assert visit.has_price_snapshot?
  end

  test "has_price_snapshot? returns false when snapshot empty" do
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1,
      price_snapshot: {}
    )

    assert_not visit.has_price_snapshot?
  end
end
