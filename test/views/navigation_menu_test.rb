# frozen_string_literal: true

require "test_helper"

class NavigationMenuTest < ActionView::TestCase
  setup do
    @user = users(:pilot)
  end

  test "menu links use turbo-action advance to update URL" do
    # Set instance variables that the partial expects
    @active_menu = :inbox

    render partial: "shared/navigation_menu", locals: {
      current_user: @user
    }

    # All main menu links should have data-turbo-action="advance"
    # This ensures the URL updates when clicking menu items
    assert_select "a[href='/inbox'][data-turbo-action='advance']"
    assert_select "a[href='/chat'][data-turbo-action='advance']"
    assert_select "a[href='/navigation'][data-turbo-action='advance']"
    assert_select "a[href='/systems'][data-turbo-action='advance']"
    assert_select "a[href='/ships'][data-turbo-action='advance']"
    assert_select "a[href='/workers'][data-turbo-action='advance']"
  end

  test "menu links still target content_panel turbo frame" do
    @active_menu = :inbox

    render partial: "shared/navigation_menu", locals: {
      current_user: @user
    }

    # Links should still target the turbo frame for fast loading
    assert_select "a[href='/inbox'][data-turbo-frame='content_panel']"
  end
end
