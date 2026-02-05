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
end
