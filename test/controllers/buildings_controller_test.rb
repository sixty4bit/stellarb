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
end
