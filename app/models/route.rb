class Route < ApplicationRecord
  include TripleId

  belongs_to :user
  belongs_to :ship, optional: true

  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active paused completed] }
  validate :validate_stops_structure

  before_validation :generate_short_id, on: :create
  after_commit :check_tutorial_completion, on: [:create, :update]

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :paused, -> { where(status: "paused") }

  # Generate short ID from route stops
  def generate_short_id
    return if short_id.present?

    if stops.any? && stops.is_a?(Array)
      # First letter of each stop
      letters = stops.map { |stop| stop["name"]&.first&.downcase }.compact.join
      base = "rt-#{letters}"
    else
      base = "rt-#{SecureRandom.hex(3)}"
    end

    candidate = base
    counter = 2

    while Route.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  # Calculate profit per hour based on recent performance
  def calculate_profit_per_hour!
    return 0.0 unless loop_count > 0 && created_at < 1.hour.ago

    hours_active = (Time.current - created_at) / 1.hour
    self.profit_per_hour = total_profit / hours_active
    save!
  end

  # ===========================================
  # Tutorial Support Methods
  # ===========================================

  # Check if route has any stops defined
  # @return [Boolean]
  def has_stops?
    stops.is_a?(Array) && stops.any?
  end

  # Check if route is profitable
  # @return [Boolean]
  def profitable?
    total_profit.present? && total_profit > 0
  end

  # Check if all stops are within The Cradle (0,0,0)
  # @return [Boolean]
  def within_cradle?
    return false unless has_stops?

    system_ids = stops.map { |stop| stop["system_id"] || stop[:system_id] }.compact
    return false if system_ids.empty?

    systems = System.where(id: system_ids)
    systems.any? && systems.all?(&:is_cradle?)
  end

  # Check if route qualifies for tutorial completion
  # Must be: active, profitable, and have stops
  # @return [Boolean]
  def qualifies_for_tutorial?
    status == "active" && profitable? && has_stops?
  end

  # Check if route meets supply chain tutorial criteria
  # Same as qualifies_for_tutorial? but semantically distinct
  # @return [Boolean]
  def meets_supply_chain_tutorial?
    qualifies_for_tutorial?
  end

  # Check if route involves a specific commodity in any stop
  # @param commodity [String] the commodity name to check
  # @return [Boolean]
  def involves_commodity?(commodity)
    return false unless has_stops?

    stops.any? do |stop|
      (stop["commodity"] || stop[:commodity]).to_s.downcase == commodity.to_s.downcase
    end
  end

  # ===========================================
  # Stop & Intent Management (vsx.16)
  # ===========================================

  # Get intents for a specific stop by index
  # @param stop_index [Integer] index of the stop
  # @return [Array<Hash>] array of intents or empty array
  def intents_at(stop_index)
    return [] unless stops.is_a?(Array) && stops[stop_index]
    stops[stop_index]["intents"] || []
  end

  # Add a new stop to the route
  # @param system_id [Integer] the system ID
  # @param system [String] the system name
  # @return [Hash] the newly created stop
  def add_stop(system_id:, system:)
    self.stops ||= []
    new_stop = {
      "system_id" => system_id,
      "system" => system,
      "intents" => []
    }
    stops << new_stop
    new_stop
  end

  # Remove a stop at the given index
  # @param stop_index [Integer] index of the stop to remove
  # @return [Hash, nil] the removed stop or nil
  def remove_stop(stop_index)
    return nil unless stops.is_a?(Array) && stops[stop_index]
    stops.delete_at(stop_index)
  end

  # Reorder a stop from one position to another
  # @param from [Integer] original index
  # @param to [Integer] target index
  def reorder_stop(from:, to:)
    return unless stops.is_a?(Array) && stops[from]
    stop = stops.delete_at(from)
    stops.insert(to, stop)
  end

  # Add an intent to a stop
  # @param stop_index [Integer] index of the stop
  # @param type [String] intent type (buy/sell/load/unload)
  # @param commodity [String] commodity name
  # @param quantity [Integer] quantity
  # @param max_price [Numeric, nil] max price for buy/load intents
  # @param min_price [Numeric, nil] min price for sell/unload intents
  # @return [Hash] the newly created intent
  def add_intent(stop_index:, type:, commodity:, quantity:, max_price: nil, min_price: nil)
    return nil unless stops.is_a?(Array) && stops[stop_index]

    stops[stop_index]["intents"] ||= []
    new_intent = {
      "type" => type,
      "commodity" => commodity,
      "quantity" => quantity
    }
    new_intent["max_price"] = max_price if max_price
    new_intent["min_price"] = min_price if min_price

    stops[stop_index]["intents"] << new_intent
    new_intent
  end

  # Remove an intent from a stop
  # @param stop_index [Integer] index of the stop
  # @param intent_index [Integer] index of the intent within the stop
  # @return [Hash, nil] the removed intent or nil
  def remove_intent(stop_index:, intent_index:)
    return nil unless stops.is_a?(Array) && stops[stop_index]
    intents = stops[stop_index]["intents"]
    return nil unless intents.is_a?(Array) && intents[intent_index]

    intents.delete_at(intent_index)
  end

  # Update an intent's properties
  # @param stop_index [Integer] index of the stop
  # @param intent_index [Integer] index of the intent
  # @param attrs [Hash] attributes to update
  def update_intent(stop_index:, intent_index:, **attrs)
    return nil unless stops.is_a?(Array) && stops[stop_index]
    intents = stops[stop_index]["intents"]
    return nil unless intents.is_a?(Array) && intents[intent_index]

    intent = intents[intent_index]
    attrs.each do |key, value|
      intent[key.to_s] = value
    end
    intent
  end

  # ===========================================
  # Route Execution (vsx.28-30)
  # ===========================================

  # Check if an intent should execute given the current market price
  # Buy/load intents execute when current_price <= max_price
  # Sell/unload intents execute when current_price >= min_price
  # @param intent [Hash] the intent to check
  # @param current_price [Numeric] the current market price for the commodity
  # @return [Boolean] true if intent should execute
  def intent_should_execute?(intent, current_price)
    type = intent["type"] || intent[:type]
    max_price = intent["max_price"] || intent[:max_price]
    min_price = intent["min_price"] || intent[:min_price]

    case type
    when "buy", "load"
      current_price <= max_price
    when "sell", "unload"
      current_price >= min_price
    else
      true # Unknown type - allow execution
    end
  end

  # Skip an intent due to price limit and send notification to user
  # @param intent [Hash] the skipped intent
  # @param current_price [Numeric] the current market price
  # @param system [System] the system where skip occurred
  def skip_and_notify_intent(intent, current_price, system)
    type = intent["type"] || intent[:type]
    commodity = intent["commodity"] || intent[:commodity]
    quantity = intent["quantity"] || intent[:quantity]
    limit_price = %w[buy load].include?(type) ? (intent["max_price"] || intent[:max_price]) : (intent["min_price"] || intent[:min_price])
    limit_type = %w[buy load].include?(type) ? "max" : "min"

    user.messages.create!(
      title: "Route intent skipped: #{commodity}",
      body: "Your trade route \"#{name}\" skipped a #{type} order for #{quantity} #{commodity} at #{system.name}.\n\n" \
            "Current price: #{current_price} cr\n" \
            "Your #{limit_type} price limit: #{limit_price} cr\n\n" \
            "The route will continue with other intents.",
      from: "Trade Automation",
      category: "route",
      urgent: false
    )
  end

  private

  # Callback: Check if this route's creation/update completes the tutorial
  # Called after commit to ensure data is persisted
  # Advances user tutorial phase if eligible
  # @return [Boolean] whether the route qualifies for tutorial completion
  def check_tutorial_completion
    return false unless qualifies_for_tutorial?

    advance_user_tutorial_if_eligible
    true
  end

  # Advance the user's tutorial phase if they're in cradle and this route qualifies
  # Only advances from cradle -> proving_ground
  def advance_user_tutorial_if_eligible
    return unless user.cradle?
    return unless meets_supply_chain_tutorial?

    user.advance_tutorial_phase!
  end

  # Validate the stops JSONB structure and intent price limits
  # buy/load intents require max_price
  # sell/unload intents require min_price
  def validate_stops_structure
    return unless stops.is_a?(Array)

    stops.each_with_index do |stop, stop_idx|
      # Validate stop has system_id
      unless stop["system_id"].present? || stop[:system_id].present?
        errors.add(:stops, "stop #{stop_idx + 1} requires system_id")
      end

      # Validate intents if present
      intents = stop["intents"] || stop[:intents] || []
      intents.each_with_index do |intent, intent_idx|
        validate_intent(intent, stop_idx, intent_idx)
      end
    end
  end

  # Validate a single intent's structure
  def validate_intent(intent, stop_idx, intent_idx)
    type = intent["type"] || intent[:type]
    commodity = intent["commodity"] || intent[:commodity]
    quantity = intent["quantity"] || intent[:quantity]
    max_price = intent["max_price"] || intent[:max_price]
    min_price = intent["min_price"] || intent[:min_price]

    label = "stop #{stop_idx + 1} intent #{intent_idx + 1}"

    # Required fields for all intents
    errors.add(:stops, "#{label} requires commodity") unless commodity.present?
    errors.add(:stops, "#{label} requires quantity") unless quantity.present?

    # buy/load require max_price
    if %w[buy load].include?(type) && !max_price.present?
      errors.add(:stops, "#{label} (#{type}) requires max_price")
    end

    # sell/unload require min_price
    if %w[sell unload].include?(type) && !min_price.present?
      errors.add(:stops, "#{label} (#{type}) requires min_price")
    end
  end
end