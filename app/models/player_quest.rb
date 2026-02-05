# frozen_string_literal: true

class PlayerQuest < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :quest

  # Status enum
  enum :status, {
    in_progress: "in_progress",
    completed: "completed",
    failed: "failed"
  }, default: :in_progress

  # Validations
  validates :user_id, uniqueness: { scope: :quest_id, message: "has already started this quest" }
  validates :status, presence: true

  # Callbacks
  before_create :set_started_at

  # Scopes
  scope :active, -> { where(status: :in_progress) }
  scope :finished, -> { where(status: :completed) }

  # ===========================================
  # Instance Methods
  # ===========================================

  # Mark quest as completed and award credits
  def complete!
    return false if completed?

    update!(
      status: :completed,
      completed_at: Time.current
    )

    # Award credits to user
    user.increment!(:credits, quest.credits_reward)

    true
  end

  # Check if quest is completable (has met objectives)
  # @return [Boolean]
  def completable?
    in_progress? && objectives_met?
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  # Placeholder for objective checking
  # Will be expanded as quest mechanics are implemented
  def objectives_met?
    # TODO: Implement objective checking based on quest.task
    true
  end
end
