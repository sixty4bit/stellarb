# frozen_string_literal: true

# Inbox messages for players
# Used for notifications, system alerts, NPC communications, etc.
class Message < ApplicationRecord
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

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
