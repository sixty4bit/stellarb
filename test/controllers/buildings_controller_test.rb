# frozen_string_literal: true

require "test_helper"

class BuildingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @building = buildings(:mining_facility)
    sign_in_as(@user)
  end

  test "index renders buildings list" do
    get buildings_path
    assert_response :success
    assert_select "h1", text: /Buildings/
  end

  test "index shows user buildings" do
    get buildings_path
    assert_response :success
    assert_select "a", text: /Alpha Mine/
  end

  test "index displays building function" do
    get buildings_path
    assert_response :success
    assert_select "*", text: /extraction/i
  end

  test "show renders building detail" do
    get building_path(@building)
    assert_response :success
    assert_select "h1", text: /Alpha Mine/
  end

  test "show displays building stats" do
    get building_path(@building)
    assert_response :success
    assert_select "*", text: /Output Rate/i
  end

  test "show has back to buildings link" do
    get building_path(@building)
    assert_response :success
    assert_select "a[href='#{buildings_path}']"
  end

  test "new renders building form" do
    get new_building_path
    assert_response :success
    assert_select "form"
  end

  # ===========================================
  # Upgrade Action Tests
  # ===========================================

  test "upgrade increments building tier" do
    @user.update!(credits: 100_000)
    original_tier = @building.tier

    post upgrade_building_path(@building)

    @building.reload
    assert_equal original_tier + 1, @building.tier
    assert_redirected_to building_path(@building)
    assert_match /upgraded to tier/i, flash[:notice]
  end

  test "upgrade deducts credits from user" do
    @user.update!(credits: 100_000)
    upgrade_cost = @building.upgrade_cost
    original_credits = @user.credits

    post upgrade_building_path(@building)

    @user.reload
    assert_equal original_credits - upgrade_cost, @user.credits
  end

  test "upgrade fails with insufficient credits" do
    @user.update!(credits: 1)
    original_tier = @building.tier

    post upgrade_building_path(@building)

    @building.reload
    assert_equal original_tier, @building.tier
    assert_redirected_to building_path(@building)
    assert_match /insufficient credits/i, flash[:alert]
  end

  test "upgrade fails for max tier building" do
    @user.update!(credits: 100_000)
    @building.update!(tier: 5)

    post upgrade_building_path(@building)

    assert_redirected_to building_path(@building)
    assert_match /cannot be upgraded/i, flash[:alert]
  end

  test "upgrade fails for disabled building" do
    @user.update!(credits: 100_000)
    @building.update!(disabled_at: Time.current)

    post upgrade_building_path(@building)

    assert_redirected_to building_path(@building)
    assert_match /cannot be upgraded/i, flash[:alert]
  end

  test "show displays upgrade cost" do
    @user.update!(credits: 100_000)
    upgrade_cost = @building.upgrade_cost

    get building_path(@building)

    assert_response :success
    assert_select "*", text: /#{number_with_delimiter(upgrade_cost)}/
  end

  test "show displays upgrade button when building is upgradeable" do
    @user.update!(credits: 100_000)

    get building_path(@building)

    assert_response :success
    assert_select "button", text: /Upgrade to T#{@building.tier + 1}/
  end

  test "show displays max tier message for tier 5 building" do
    @building.update!(tier: 5)

    get building_path(@building)

    assert_response :success
    assert_select "span", text: /Max Tier/
  end

  # ===========================================
  # Upgrade Effects Display Tests
  # ===========================================

  test "show displays current tier effects section" do
    # Use defense building which doesn't require specialization
    @building.update!(function: "defense", tier: 2, status: "active")

    get building_path(@building)

    assert_response :success
    # Should show tier effects section with current tier label
    assert_select ".tier-effects"
    assert_select ".tier-effects", text: /Tier 2/i
  end

  test "show displays upgrade preview for upgradeable building" do
    @building.update!(function: "defense", tier: 2, status: "active", disabled_at: nil)
    @user.update!(credits: 100_000)

    get building_path(@building)

    assert_response :success
    # Should show next tier preview
    assert_select ".upgrade-preview"
    assert_select ".upgrade-preview", text: /After Upgrade/i
    assert_select ".upgrade-preview", text: /Tier 3/i
  end

  test "show displays upgrade cost in preview" do
    @building.update!(function: "defense", tier: 2, status: "active", disabled_at: nil)
    @user.update!(credits: 1_000_000)
    
    # Cost to upgrade from T2 to T3
    upgrade_cost = @building.upgrade_cost

    get building_path(@building)

    assert_response :success
    assert_select ".upgrade-preview", text: /#{number_with_delimiter(upgrade_cost)}/
  end

  test "show displays next tier effects for logistics building upgrade" do
    # Create logistics building (need no existing warehouse)
    system_without_warehouse = systems(:alpha_centauri)
    system_without_warehouse.buildings.where(function: "logistics").destroy_all
    
    warehouse = Building.create!(
      name: "Test Warehouse",
      function: "logistics",
      tier: 1,
      race: "vex",
      user: @user,
      system: system_without_warehouse,
      status: "active"
    )
    @user.update!(credits: 100_000)

    get building_path(warehouse)

    assert_response :success
    # Current tier shows capacity bonus
    assert_select ".tier-effects", text: /Capacity Bonus/i
    # Next tier preview shows upgraded stats
    assert_select ".upgrade-preview", text: /Capacity Bonus/i
  end

  test "show displays next tier effects for civic building upgrade" do
    # Create civic building (need no existing marketplace)
    system = systems(:alpha_centauri)
    system.buildings.where(function: "civic").destroy_all
    
    marketplace = Building.create!(
      name: "Test Marketplace",
      function: "civic",
      tier: 2,
      race: "vex",
      user: @user,
      system: system,
      status: "active"
    )
    @user.update!(credits: 100_000)

    get building_path(marketplace)

    assert_response :success
    # Current tier effects section
    assert_select ".tier-effects", text: /Fee/i
    # Next tier preview
    assert_select ".upgrade-preview", text: /Fee/i
  end

  test "show does not display upgrade preview for max tier building" do
    @building.update!(function: "defense", tier: 5, status: "active")

    get building_path(@building)

    assert_response :success
    assert_select ".upgrade-preview", count: 0
  end

  private

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
