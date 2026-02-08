class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :system

  validates :user, presence: true
  validates :system, presence: true
  validates :system_id, uniqueness: { scope: :user_id, message: "has already been bookmarked" }
end
