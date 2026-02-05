# frozen_string_literal: true

require "test_helper"

class ChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:pilot)
    sign_in_as(@user)
  end

  test "index renders chat interface" do
    get chat_index_path
    assert_response :success
    assert_select "h1", text: /Chat/
  end

  test "index shows channel tabs" do
    get chat_index_path
    assert_response :success
    assert_select "a", text: /Global/
    assert_select "a", text: /Trade/
  end

  test "index has message input field" do
    get chat_index_path
    assert_response :success
    assert_select "input[type='text']" or assert_select "textarea"
  end

  test "index displays message area" do
    get chat_index_path
    assert_response :success
    assert_select "[data-controller='chat']"
  end
end
