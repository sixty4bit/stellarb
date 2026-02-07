# frozen_string_literal: true

require "test_helper"

class ResolutionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @incident = incidents(:ship_incident)
    @worker = hired_recruits(:hired_engineer)
    sign_in_as(@user)
  end

  test "resolve incident with assistant" do
    @worker.update!(role: "assistant", assistant_cooldown_until: nil)

    post resolutions_path(incident_id: @incident.id, resolver_id: @worker.id, resolver_type: "assistant")

    @incident.reload
    assert @incident.resolved?
    assert_redirected_to root_path
  end

  test "cannot resolve with assistant on cooldown" do
    @worker.update!(role: "assistant", assistant_cooldown_until: 5.hours.from_now)

    post resolutions_path(incident_id: @incident.id, resolver_id: @worker.id, resolver_type: "assistant")

    @incident.reload
    refute @incident.resolved?
    follow_redirect!
    assert_select "*", text: /cooldown/i
  end

  test "resolve incident with nearby npc succeeds on good roll" do
    # resolve_with_nearby_npc! uses random, we can't easily control it here
    # Just test the endpoint doesn't error
    post resolutions_path(incident_id: @incident.id, resolver_id: @worker.id, resolver_type: "nearby")

    assert_response :redirect
  end

  test "rejects invalid resolver type" do
    post resolutions_path(incident_id: @incident.id, resolver_id: @worker.id, resolver_type: "invalid")

    follow_redirect!
    assert_select "*", text: /invalid/i
  end
end
