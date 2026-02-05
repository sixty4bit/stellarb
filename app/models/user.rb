class User < ApplicationRecord
  # Associations
  has_many :ships, dependent: :destroy
  has_many :buildings, dependent: :destroy
  has_many :discovered_systems, class_name: 'System', foreign_key: 'discovered_by_id'
  has_many :hirings, dependent: :destroy
  has_many :hired_recruits, through: :hirings
  has_many :system_visits, dependent: :destroy
  has_many :visited_systems, through: :system_visits, source: :system
  has_many :routes, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :level_tier, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :credits, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :generate_short_id, on: :create

  private

  def generate_short_id
    return if short_id.present?

    base = "u-#{name[0, 3].downcase}" if name.present?
    base ||= "u-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while User.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end
end
