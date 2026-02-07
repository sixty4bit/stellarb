require "test_helper"

class FlavorTextTest < ActiveSupport::TestCase
  EXPECTED_CONTEXTS = %i[
    docking fuel_low purchase combat_miss combat_hit
    exploration_empty exploration_discovery npc_hired npc_fired
    trade_profit trade_loss error_404 maintenance
    empty_inbox no_ships no_cargo level_up chaos_event
    oregon_trail
  ].freeze

  test "all expected contexts are defined" do
    EXPECTED_CONTEXTS.each do |ctx|
      assert FlavorText::TEXTS.key?(ctx), "Missing context: #{ctx}"
    end
  end

  test "each context has at least 5 entries" do
    EXPECTED_CONTEXTS.each do |ctx|
      assert FlavorText::TEXTS[ctx].size >= 5, "Context #{ctx} has fewer than 5 entries"
    end
  end

  test ".for returns a string" do
    EXPECTED_CONTEXTS.each do |ctx|
      result = FlavorText.for(ctx)
      assert_kind_of String, result
      assert result.present?, "FlavorText.for(#{ctx}) returned blank"
    end
  end

  test ".for with unknown context returns fallback" do
    result = FlavorText.for(:nonexistent)
    assert_kind_of String, result
  end
end
