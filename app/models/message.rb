# frozen_string_literal: true

# Inbox messages for players
# Used for notifications, system alerts, NPC communications, etc.
class Message < ApplicationRecord
  include Turbo::Broadcastable

  # Associations
  belongs_to :user

  # Validations
  validates :title, presence: true
  validates :body, presence: true
  validates :from, presence: true
  validates :uuid, uniqueness: true, allow_nil: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :urgent, -> { where(urgent: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent_first, -> { order(created_at: :desc) }

  # Callbacks
  before_create :generate_uuid
  after_create_commit :broadcast_unread_badge
  after_create_commit :broadcast_notification_sound
  after_destroy_commit :broadcast_unread_badge
  after_update_commit :broadcast_unread_badge, if: :saved_change_to_read_at?

  # Instance methods

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_read!
    update!(read_at: Time.current)
  end

  def urgent?
    urgent == true
  end

  # Returns the Turbo Stream target for this user's unread badge
  def broadcast_unread_badge_target
    "inbox_unread_badge_user_#{user_id}"
  end

  # Broadcasts an update to the user's unread badge via Turbo Streams
  # Gracefully handles missing ActionCable in test environment
  def broadcast_unread_badge
    return unless defined?(ActionCable)

    broadcast_replace_later_to(
      broadcast_unread_badge_target,
      target: "inbox_unread_badge",
      partial: "shared/unread_badge",
      locals: { user: user }
    )
  end

  # Broadcasts a notification sound to the user's #sounds container
  # The sound partial respects user's sound_enabled preference
  def broadcast_notification_sound
    return unless defined?(ActionCable)

    broadcast_append_later_to(
      "user_#{user_id}_notifications",
      target: "sounds",
      partial: "shared/notification_sound"
    )
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
