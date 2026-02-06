# frozen_string_literal: true

require "test_helper"

class SoundHelperTest < ActionView::TestCase
  include SoundHelper

  test "sound_tag renders audio element with stimulus controller" do
    result = sound_tag("/sounds/notification.mp3")

    assert_includes result, 'data-controller="audio"'
    assert_includes result, 'data-audio-src-value="/sounds/notification.mp3"'
    assert_includes result, 'data-audio-autoplay-value="true"'
    assert_includes result, 'data-audio-volume-value="0.5"'
  end

  test "sound_tag respects custom volume" do
    result = sound_tag("/sounds/notification.mp3", volume: 0.3)

    assert_includes result, 'data-audio-volume-value="0.3"'
  end

  test "sound_tag respects autoplay false" do
    result = sound_tag("/sounds/notification.mp3", autoplay: false)

    assert_includes result, 'data-audio-autoplay-value="false"'
  end
end
