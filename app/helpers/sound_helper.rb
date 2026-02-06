# frozen_string_literal: true

# Helper methods for triggering sounds via Turbo Streams.
#
# Usage in controllers:
#   include SoundHelper
#   
#   def create
#     @message = Message.create!(message_params)
#     respond_to do |format|
#       format.turbo_stream do
#         render turbo_stream: [
#           turbo_stream.append(:messages, @message),
#           sound_stream("/sounds/notifications/message.mp3")
#         ]
#       end
#     end
#   end
#
# Usage in views:
#   <%= sound_tag "/sounds/ui/click.mp3", autoplay: true %>
#
module SoundHelper
  # Renders an audio element that auto-plays when connected.
  # Useful for playing sounds when new content appears via Turbo.
  #
  # @param src [String] Path to the sound file (e.g., "/sounds/notification.mp3")
  # @param volume [Float] Volume level from 0.0 to 1.0 (default: 0.5)
  # @param autoplay [Boolean] Whether to play immediately on connect (default: true)
  #
  def sound_tag(src, volume: 0.5, autoplay: true)
    tag.div(
      data: {
        controller: "audio",
        audio_src_value: src,
        audio_volume_value: volume,
        audio_autoplay_value: autoplay
      }
    )
  end

  # Returns a Turbo Stream action that appends a sound element to the #sounds container.
  # Call this from a controller to trigger a sound via Turbo Stream response.
  #
  # @param src [String] Path to the sound file
  # @param volume [Float] Volume level from 0.0 to 1.0 (default: 0.5)
  #
  def sound_stream(src, volume: 0.5)
    turbo_stream.append(:sounds) do
      sound_tag(src, volume: volume, autoplay: true)
    end
  end
end
