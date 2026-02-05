# frozen_string_literal: true

require "test_helper"

# Task stellarb-58p: CLI text views for recruiter
# Verifies the recruiter views follow CLI-style formatting per ROADMAP Section 7
class RecruitersViewsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
    @recruit = recruits(:engineer_bob)
  end

  # ================================================
  # Index View CLI Elements
  # ================================================

  test "index has keyboard shortcut hints" do
    get recruiters_path
    assert_response :success
    assert_select "*", text: /j\/k/i # Navigate hint
    assert_select "*", text: /Enter/i # Select hint
    assert_select "*", text: /h to hire/i
  end

  test "index uses terminal color palette" do
    get recruiters_path
    assert_response :success
    # Orange primary accent
    assert_select "h1.text-orange-500"
    # Blue background elements
    assert_select ".bg-blue-900"
    # Lime green for positive elements
    assert_select ".text-lime-400"
  end

  test "index shows recruiter pool status header" do
    get recruiters_path
    assert_response :success
    assert_select ".text-gray-400", text: /Level.*pool/i
  end

  test "index uses monospace for numerical data" do
    get recruiters_path
    assert_response :success
    assert_select ".font-mono"
  end

  # ================================================
  # Show View CLI Elements (Resume Format)
  # ================================================

  test "show displays name in resume header format" do
    get recruiter_path(@recruit)
    assert_response :success
    # Name and class should be prominent
    assert_select "h1.text-orange-500", text: /Engineer/i
  end

  test "show displays stats in grid layout" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select ".grid" do
      assert_select "*", text: /Skill/i
      assert_select "*", text: /Chaos Factor/i
      assert_select "*", text: /Base Wage/i
      assert_select "*", text: /Hire cost/i
    end
  end

  test "show employment history uses border-left timeline style" do
    get recruiter_path(@recruit)
    assert_response :success
    # Timeline-style left border for each entry
    assert_select ".border-l-2"
  end

  test "show has risk assessment panel for high chaos" do
    marine = recruits(:marine_grunt) # chaos_factor 60
    get recruiter_path(marine)
    assert_response :success
    assert_select ".bg-orange-900\\/50", text: /Risk Assessment/i
  end

  test "show has availability countdown" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /Available for:/i
  end

  test "show has keyboard shortcut hints" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /h to hire/i
    assert_select "*", text: /q to go back/i
  end

  # ================================================
  # CLI Color Coding
  # ================================================

  test "rarity colors are correct" do
    navigator = recruits(:navigator_zara) # skill 82 = rare
    get recruiter_path(navigator)
    assert_response :success
    assert_select ".bg-purple-800", text: /RARE/i
  end

  test "skill colors use lime for high skill" do
    navigator = recruits(:navigator_zara) # skill 82
    get recruiter_path(navigator)
    assert_response :success
    assert_select ".text-lime-400", text: /82/
  end

  test "chaos colors use orange for medium chaos" do
    navigator = recruits(:navigator_zara) # chaos 45
    get recruiter_path(navigator)
    assert_response :success
    assert_select ".text-yellow-400", text: /45/
  end

  # ================================================
  # Employment History Format
  # ================================================

  test "employment history shows employer name" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select ".font-bold", text: /Stellar Mining Corp/i
  end

  test "employment history shows duration" do
    get recruiter_path(@recruit)
    assert_response :success
    assert_select "*", text: /months/i
  end

  test "employment history shows outcome with color coding" do
    get recruiter_path(@recruit)
    assert_response :success
    # Contract completed should be gray (clean exit)
    assert_select ".text-gray-400", text: /Contract completed/i
  end

  test "incident outcomes are highlighted in orange" do
    marine = recruits(:marine_grunt) # has "Cargo incident (T2)"
    get recruiter_path(marine)
    assert_response :success
    assert_select ".text-orange-400", text: /Cargo incident/i
  end
end
