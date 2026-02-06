# frozen_string_literal: true

require "test_helper"

class InboxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    @message = messages(:pilot_welcome)
    sign_in_as(@user)
  end

  test "index renders inbox list with messages" do
    get inbox_index_path
    assert_response :success
    assert_select "h1", text: /Inbox/
    assert_select "[data-controller='inbox-list']"
  end

  test "index shows message titles" do
    get inbox_index_path
    assert_response :success
    assert_select ".font-bold", minimum: 1
  end

  test "index displays keyboard help hint" do
    get inbox_index_path
    assert_response :success
    assert_select "p", text: /j\/k to navigate/
  end

  test "show renders message detail view" do
    get inbox_path(@message)
    assert_response :success
    assert_select "h2", text: /Welcome/i
  end

  test "show displays message body and sender" do
    get inbox_path(@message)
    assert_response :success
    assert_select ".text-gray-400", text: /Colonial Authority/
  end

  test "show has back to inbox link" do
    get inbox_path(@message)
    assert_response :success
    assert_select "a[href='#{inbox_index_path}']"
  end
end
