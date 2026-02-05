class SystemVisit < ApplicationRecord
  belongs_to :user
  belongs_to :system

  validates :first_visited_at, presence: true
  validates :last_visited_at, presence: true
  validates :visit_count, presence: true, numericality: { greater_than: 0 }
  validates :user_id, uniqueness: { scope: :system_id, message: "has already visited this system" }

  # Scopes for ordering
  scope :by_first_visit, -> { order(first_visited_at: :asc) }
  scope :by_last_visit, -> { order(last_visited_at: :desc) }

  # Record a new visit to a system
  def self.record_visit(user, system)
    visit = find_or_initialize_by(user: user, system: system)

    if visit.new_record?
      visit.first_visited_at = Time.current
      visit.last_visited_at = Time.current
      visit.visit_count = 1
    else
      visit.last_visited_at = Time.current
      visit.visit_count += 1
    end

    visit.save!
    visit
  end
end