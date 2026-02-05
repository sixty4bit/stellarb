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
  }, suffix: true

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

  # Terminate employment and record in employment history
  def terminate!(reason = 'fired')
    termination_time = Time.current
    
    # Calculate employment duration in months
    duration_months = ((termination_time - hired_at) / 1.month).round
    duration_months = 1 if duration_months < 1 # Minimum 1 month
    
    # Record in employment history
    hired_recruit.add_employment_record(
      employer: user.name,
      duration_months: duration_months,
      outcome: "Terminated (#{reason})"
    )
    
    update!(
      status: reason,
      terminated_at: termination_time
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
