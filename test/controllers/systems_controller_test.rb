# frozen_string_literal: true

require "test_helper"

class SystemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @cradle = systems(:cradle)
    sign_in_as(@user)
  end

  test "index renders systems list" do
    get systems_path
    assert_response :success
    assert_select "h1", text: /Systems/
  end

  test "index shows visited systems" do
    get systems_path
    assert_response :success
    # User has visited The Cradle via fixture
    assert_select "a", text: /The Cradle/
  end

  test "index displays system coordinates" do
    get systems_path
    assert_response :success
    assert_select ".text-gray-500", text: /900.*900.*900/
  end

  test "show renders system detail" do
    get system_path(@cradle)
    assert_response :success
    assert_select "h1", text: /The Cradle/
  end

  test "show displays star type" do
    get system_path(@cradle)
    assert_response :success
    assert_select "*", text: /yellow.*dwarf/i
  end

  test "show has back to systems link" do
    get system_path(@cradle)
    assert_response :success
    assert_select "a[href='#{systems_path}']"
  end

  # === Buildable Buildings Section (Task 8dl) ===

  test "show displays buildable buildings section" do
    get system_path(@cradle)
    assert_response :success
    assert_select "h2", text: /Build New Structures/i
  end

  test "show displays all 4 buildable building types" do
    get system_path(@cradle)
    assert_response :success

    # Mine (extraction)
    assert_select "*", text: /Mine/i
    # Warehouse (logistics)
    assert_select "*", text: /Warehouse/i
    # Marketplace (civic)
    assert_select "*", text: /Marketplace/i
    # Factory (refining)
    assert_select "*", text: /Factory/i
  end

  test "show displays build button for each building type" do
    get system_path(@cradle)
    assert_response :success

    # Should have 4 build buttons/links
    assert_select "a[href*='buildings/new']", minimum: 4
  end

  test "build buttons link to new building form with system pre-filled" do
    get system_path(@cradle)
    assert_response :success

    # Build links should include system_id param
    assert_select "a[href*='system_id=#{@cradle.id}']", minimum: 4
  end

  test "build buttons include function parameter" do
    get system_path(@cradle)
    assert_response :success

    # Each build link should have the function param
    assert_select "a[href*='function=extraction']"
    assert_select "a[href*='function=logistics']"
    assert_select "a[href*='function=civic']"
    assert_select "a[href*='function=refining']"
  end

  test "system show loads in under 100ms" do
    # Warm up
    get system_path(@cradle)

    # Measure
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get system_path(@cradle)
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000

    assert_response :success
    assert elapsed_ms < 100, "System show took #{elapsed_ms.round(1)}ms, expected < 100ms"
  end
end
