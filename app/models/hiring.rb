class Hiring < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :hired_recruit
  belongs_to :assignable, polymorphic: true, optional: true

  # Enums
  enum :status, {
    active: "active",
    fired: "fired",
    deceased: "deceased",
    retired: "retired",
    striking: "striking"
  }, _suffix: true

  # Validations
  validates :status, presence: true
  validates :wage, presence: true, numericality: { greater_than: 0 }
  validates :hired_at, presence: true

  # Ensure a hired recruit can only have one active hiring per user
  validates :hired_recruit_id, uniqueness: {
    scope: :user_id,
    conditions: -> { where(status: 'active') },
    message: "is already actively employed by this user"
  }

  # Callbacks
  before_validation :set_hired_at, on: :create
  before_validation :set_wage, on: :create

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :terminated, -> { where.not(status: 'active') }
  scope :unassigned, -> { where(assignable: nil) }

  # Terminate employment
  def terminate!(reason = 'fired')
    update!(
      status: reason,
      terminated_at: Time.current,
      assignable: nil
    )
  end

  # Assign to a ship or building
  def assign_to!(asset)
    update!(assignable: asset)
  end

  # Remove from assignment but keep employed
  def unassign!
    update!(assignable: nil)
  end

  private

  def set_hired_at
    self.hired_at ||= Time.current
  end

  def set_wage
    self.wage ||= hired_recruit.calculate_wage
  end
end
