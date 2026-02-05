class PlayerHub < ApplicationRecord
  # Associations
  belongs_to :owner, class_name: "User"
  belongs_to :system
  has_many :immigrants, class_name: "User", foreign_key: "emigration_hub_id"

  # Validations
  validates :owner, presence: true
  validates :system, presence: true
  validates :system_id, uniqueness: true
  validates :security_rating, numericality: { in: 0..100 }, allow_nil: true
  validates :tax_rate, numericality: { in: 0..100 }, allow_nil: true

  # Scopes
  scope :certified, -> { where(certified: true) }
  scope :for_emigration, -> { certified.where("security_rating >= ?", 20).order(security_rating: :desc) }

  # Security level thresholds
  SECURITY_LEVELS = {
    (80..100) => "High Security",
    (50..79)  => "Moderate",
    (20..49)  => "Low Security",
    (0..19)   => "Lawless"
  }.freeze

  # ===========================================
  # Dossier (Hub Information for Emigration)
  # ===========================================

  # Generate a dossier containing all information needed for emigration selection
  # This is what players see when choosing where to immigrate
  #
  # @return [Hash] Complete hub information
  def dossier
    {
      # Owner information
      owner_name: owner.name,

      # System information
      system_name: system.name,
      coordinates: {
        x: system.x,
        y: system.y,
        z: system.z
      },
      distance_from_cradle: distance_from_cradle,

      # Security & governance
      security_rating: security_rating,
      security_level: security_level,
      tax_rate: tax_rate,

      # Economic indicators
      resource_prices: resource_prices,
      economic_liquidity: economic_liquidity,
      active_buy_orders: active_buy_orders,

      # Immigration stats
      immigration_count: immigration_count
    }
  end

  # ===========================================
  # Security Level Classification
  # ===========================================

  # Returns human-readable security level based on rating
  # @return [String] Security classification
  def security_level
    SECURITY_LEVELS.find { |range, _| range.include?(security_rating || 0) }&.last || "Unknown"
  end

  # ===========================================
  # Geographic Calculations
  # ===========================================

  # Calculate distance from The Cradle (0,0,0)
  # @return [Float] Euclidean distance in game units
  def distance_from_cradle
    return 0.0 unless system

    Math.sqrt(system.x**2 + system.y**2 + system.z**2)
  end

  # ===========================================
  # Resource Prices
  # ===========================================

  # Get current resource prices at this hub's system
  # Combines base prices with any deltas
  #
  # @return [Hash] Commodity => price
  def resource_prices
    system&.current_prices || system&.base_prices || {}
  end

  # ===========================================
  # Immigration Tracking
  # ===========================================

  # Record a new player immigrating to this hub
  # Called when a player completes emigration and chooses this hub
  def record_immigration!
    increment!(:immigration_count)
  end
end
