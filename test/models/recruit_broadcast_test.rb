# frozen_string_literal: true

require "test_helper"

class RecruitBroadcastTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "recruit class has broadcast_pool_update class method" do
    assert Recruit.respond_to?(:broadcast_pool_update),
      "Recruit should respond to broadcast_pool_update"
  end

  test "recruit class has broadcast_pool_target class method" do
    assert Recruit.respond_to?(:broadcast_pool_target),
      "Recruit should respond to broadcast_pool_target"
  end

  test "broadcast_pool_target returns correct stream name for tier" do
    expected_target = "recruits_tier_1"
    assert_equal expected_target, Recruit.broadcast_pool_target(1)

    expected_target_2 = "recruits_tier_2"
    assert_equal expected_target_2, Recruit.broadcast_pool_target(2)
  end

  test "generate! calls broadcast_pool_update for the correct tier" do
    broadcast_tiers = []

    # Store original method if it exists
    if Recruit.respond_to?(:broadcast_pool_update)
      original_method = Recruit.method(:broadcast_pool_update)
    end

    Recruit.define_singleton_method(:broadcast_pool_update) do |tier|
      broadcast_tiers << tier
    end

    recruit = Recruit.generate!(level_tier: 1)

    assert_includes broadcast_tiers, 1, "broadcast_pool_update should be called for tier 1"
  ensure
    # Clean up or restore
    if original_method
      Recruit.define_singleton_method(:broadcast_pool_update, original_method)
    elsif Recruit.singleton_methods.include?(:broadcast_pool_update)
      Recruit.singleton_class.remove_method(:broadcast_pool_update)
    end
  end

  test "expire! calls broadcast_pool_update for the correct tier" do
    # First generate a recruit (this will call broadcast but we don't care yet)
    recruit = Recruit.generate!(level_tier: 1)

    broadcast_tiers = []

    # Store original method if it exists
    if Recruit.respond_to?(:broadcast_pool_update)
      original_method = Recruit.method(:broadcast_pool_update)
    end

    Recruit.define_singleton_method(:broadcast_pool_update) do |tier|
      broadcast_tiers << tier
    end

    recruit.expire!

    assert_includes broadcast_tiers, 1, "broadcast_pool_update should be called for tier 1"
  ensure
    # Clean up or restore
    if original_method
      Recruit.define_singleton_method(:broadcast_pool_update, original_method)
    elsif Recruit.singleton_methods.include?(:broadcast_pool_update)
      Recruit.singleton_class.remove_method(:broadcast_pool_update)
    end
  end

  test "recruit includes Turbo::Broadcastable" do
    assert Recruit.include?(Turbo::Broadcastable),
      "Recruit should include Turbo::Broadcastable"
  end
end
