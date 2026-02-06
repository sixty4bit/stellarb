# System Marketplace Design

## Overview

The System Marketplace is where players buy and sell commodities within a star system. Each system has a unique marketplace with procedurally generated base prices, dynamic price shifts based on trading activity, and visibility governed by the Market Fog of War rules.

**Key Design Principle:** Markets are the economic heartbeat of systems. They create arbitrage opportunities that drive the core trading loop and fund infrastructure expansion.

## Current Implementation Status

### Implemented
- `MarketController` with basic buy/sell actions
- `PriceDelta` model for Static + Dynamic pricing
- Market view UI with commodity table
- Ship cargo integration (add/remove cargo)

### Not Yet Implemented
- Procedural market data generation (currently hardcoded)
- Market Fog of War (staleness mechanics)
- Price trends based on actual trading
- System-specific commodity availability
- Market inventory tracking
- Buy/sell spread calculation

### Ship Model
The player controls **one ship at a time** - their "current ship". Other ships in their fleet run automated routes independently. When trading at a marketplace, the player always uses `current_user.current_ship`. There is no ship selection UI.

## Core Concepts

### 1. The "Static + Dynamic" Pricing Model

From PRD Section 4.1:

```
Current Price = Base Price + Price Delta
```

| Component | Source | Storage |
|-----------|--------|---------|
| Base Price | Procedurally generated from system seed | `system.properties["base_prices"]` (JSONB) |
| Price Delta | Accumulated from buy/sell transactions | `price_deltas` table |

**Why this model:**
- Base prices are deterministic (same seed = same prices)
- Only deltas need storage (minimal DB footprint)
- Prices naturally return to baseline over time (delta decay)

### 2. Market Fog of War

From PRD Section 6.1:

> Market data (Prices, Inventory) is **NOT** globally available. A player can only view market data for systems they have **personally visited** (docked at).

**Visibility Rules:**

| System Status | Data Shown | Freshness |
|---------------|------------|-----------|
| Never visited | Hidden (no access) | N/A |
| Visited (historical) | Last known prices | Snapshot at last visit |
| Active presence (ship/building) | Live data | Real-time |
| Active presence (spy) | Live data | Real-time |

**Staleness Mechanics:**
- When a player visits a system, a price snapshot is stored in `system_visits`
- Historical prices display with a timestamp: "Prices as of 2 hours ago"
- Live prices show no timestamp (current)

### 3. Commodities

Commodities are system-specific based on mineral distribution and star type.

**Universal Commodities** (available everywhere):
- `fuel` - Required for travel
- `food` - Crew sustenance
- `water` - Basic necessity

**System-Specific Commodities:**
- Determined by `system.properties["mineral_distribution"]`
- Refined goods based on local production capacity
- Luxury goods in developed systems

### 4. Buy/Sell Spread

The market takes a cut on every transaction:

```
Buy Price  = Base Price * 1.10  (player pays 10% premium)
Sell Price = Base Price * 0.90  (player receives 10% less)
```

The 20% spread represents the market maker's profit and creates meaningful arbitrage opportunities between systems.

## Data Model

### Existing Schema

```ruby
# price_deltas table
class PriceDelta < ApplicationRecord
  belongs_to :system

  # Columns: system_id, commodity, delta_cents
  validates :commodity, uniqueness: { scope: :system_id }
end

# system.properties (JSONB)
{
  "base_prices" => {
    "ore" => 50,
    "water" => 30,
    "fuel" => 100,
    ...
  }
}
```

### New: Price Snapshots for Fog of War

```ruby
# Add to system_visits table
class SystemVisit < ApplicationRecord
  belongs_to :user
  belongs_to :system

  # New column: price_snapshot (JSONB)
  # Stores { commodity => price } at time of visit

  def stale?
    last_visit_at < 1.hour.ago
  end

  def staleness_label
    if last_visit_at > 5.minutes.ago
      nil # Fresh
    elsif last_visit_at > 1.hour.ago
      "#{time_ago_in_words(last_visit_at)} ago"
    else
      "Prices may have changed significantly"
    end
  end
end
```

### New: Market Inventory

```ruby
# market_inventories table
class MarketInventory < ApplicationRecord
  belongs_to :system

  # Columns: system_id, commodity, quantity, restock_rate
  # quantity: Current stock available
  # restock_rate: Units regenerated per hour (procedurally set)

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  def can_sell?(amount)
    quantity >= amount
  end

  def deplete!(amount)
    update!(quantity: [quantity - amount, 0].max)
  end

  def restock!(amount = restock_rate)
    update!(quantity: quantity + amount)
  end
end
```

## UI Design

### Market Index View

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    ALPHA CENTAURI TRADING POST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Credits: 15,420 cr                          Ship: Yamato (120/200 cargo)

Commodity      Buy       Sell      Stock    Trend    [Qty]  Actions
─────────────────────────────────────────────────────────────────────
Ore            55 cr     45 cr     1,000    ↑        [___]  [B] [S]
Water          33 cr     27 cr       500    →        [___]  [B] [S]
Fuel          110 cr     90 cr       250    ↓        [___]  [B] [S]
Electronics   220 cr    180 cr       100    ↑        [___]  [B] [S]
─────────────────────────────────────────────────────────────────────
                                            Prices as of 15 min ago

[← Back to System]

j/k: Navigate  b: Buy  s: Sell  q: Quantity  Esc: Back
```

### Keyboard Navigation

| Key | Action |
|-----|--------|
| `j` | Move selection down |
| `k` | Move selection up |
| `b` | Buy selected commodity |
| `s` | Sell selected commodity |
| `q` | Edit quantity for selected row |
| `1-9` | Quick-set quantity |
| `Enter` | Execute transaction |
| `Esc` | Back to system view |

## Controller Actions

### `MarketController#index`

```ruby
def index
  # Fog of War check
  @visit = current_user.system_visits.find_by(system: @system)

  unless @visit
    redirect_to systems_path, alert: "You must visit a system before viewing its market."
    return
  end

  # Determine data freshness
  @has_presence = current_user.has_presence_in?(@system)

  if @has_presence
    @market_data = generate_live_market_data
    @staleness = nil
  else
    @market_data = @visit.price_snapshot || generate_live_market_data
    @staleness = @visit.staleness_label
  end

  # Player's current ship (the one they're piloting)
  @ship = current_user.current_ship
end

private

def generate_live_market_data
  commodities = @system.available_commodities

  commodities.map do |commodity|
    base_price = @system.base_prices[commodity]
    current_price = @system.current_price(commodity)
    inventory = MarketInventory.find_by(system: @system, commodity: commodity)

    {
      commodity: commodity,
      buy_price: (current_price * 1.10).round,  # 10% markup
      sell_price: (current_price * 0.90).round, # 10% discount
      inventory: inventory&.quantity || 0,
      trend: calculate_trend(commodity),
      base_price: base_price
    }
  end
end
```

### `MarketController#buy`

```ruby
def buy
  ship = current_user.current_ship
  commodity = params[:commodity]
  quantity = params[:quantity].to_i

  # Validations
  market_item = generate_live_market_data.find { |m| m[:commodity] == commodity }
  return redirect_with_alert("Unknown commodity") unless market_item

  price = market_item[:buy_price]
  total_cost = price * quantity

  # Check inventory
  inventory = MarketInventory.find_by(system: @system, commodity: commodity)
  return redirect_with_alert("Insufficient market stock") if inventory && inventory.quantity < quantity

  # Check credits
  return redirect_with_alert("Insufficient credits") if current_user.credits < total_cost

  # Check cargo space
  return redirect_with_alert("Insufficient cargo space") if ship.available_cargo_space < quantity

  # Execute transaction
  ActiveRecord::Base.transaction do
    current_user.update!(credits: current_user.credits - total_cost)
    ship.add_cargo!(commodity, quantity)
    inventory&.deplete!(quantity)

    # Apply price delta (buying increases price)
    PriceDelta.simulate_buy(@system, commodity, quantity)
  end

  redirect_to system_market_index_path(@system),
    notice: "Purchased #{quantity} #{commodity} for #{total_cost} cr"
end
```

### `MarketController#sell`

```ruby
def sell
  ship = current_user.current_ship
  commodity = params[:commodity]
  quantity = params[:quantity].to_i

  # Validations
  market_item = generate_live_market_data.find { |m| m[:commodity] == commodity }
  return redirect_with_alert("Unknown commodity") unless market_item

  cargo_qty = ship.cargo_quantity_for(commodity)
  return redirect_with_alert("You don't have any #{commodity}") if cargo_qty == 0
  return redirect_with_alert("Insufficient cargo") if cargo_qty < quantity

  price = market_item[:sell_price]
  total_income = price * quantity

  # Execute transaction
  ActiveRecord::Base.transaction do
    current_user.update!(credits: current_user.credits + total_income)
    ship.remove_cargo!(commodity, quantity)

    inventory = MarketInventory.find_or_create_by!(system: @system, commodity: commodity)
    inventory.update!(quantity: inventory.quantity + quantity)

    # Apply price delta (selling decreases price)
    PriceDelta.simulate_sell(@system, commodity, quantity)
  end

  redirect_to system_market_index_path(@system),
    notice: "Sold #{quantity} #{commodity} for #{total_income} cr"
end
```

## Price Dynamics

### Trend Calculation

```ruby
def calculate_trend(commodity)
  # Compare current delta to recent average
  delta = PriceDelta.find_by(system: @system, commodity: commodity)
  return :stable unless delta

  if delta.delta_cents > 10
    :up
  elsif delta.delta_cents < -10
    :down
  else
    :stable
  end
end
```

### Delta Decay (Background Job)

Prices naturally return to base over time:

```ruby
class PriceDeltaDecayJob < ApplicationJob
  queue_as :low_priority

  def perform
    PriceDelta.where.not(delta_cents: 0).find_each do |delta|
      # Decay by 5% per hour toward zero
      decay_amount = (delta.delta_cents.abs * 0.05).ceil

      if delta.delta_cents > 0
        delta.update!(delta_cents: [delta.delta_cents - decay_amount, 0].max)
      else
        delta.update!(delta_cents: [delta.delta_cents + decay_amount, 0].min)
      end
    end
  end
end
```

### Market Restock (Background Job)

```ruby
class MarketRestockJob < ApplicationJob
  queue_as :low_priority

  def perform
    MarketInventory.find_each do |inventory|
      inventory.restock!
    end
  end
end
```

## Integration Points

### With Trade Routes (Automated Ships)

Automated route ships use the **same marketplace system** as manual trading. This is critical for emergent PvP - other players can manipulate prices to disrupt competitor routes.

When a route executes an intent:

```ruby
# In RouteExecutionJob
def execute_intent(ship, stop, intent, system)
  # Uses LIVE prices - same as manual trading
  current_price = system.current_price(intent["commodity"])

  case intent["type"]
  when "buy"
    if current_price > intent["max_price"]
      notify_skipped_intent(intent, current_price)
      return :skipped
    end
    # Execute purchase - affects price_deltas (raises price)
    execute_buy(ship, system, intent["commodity"], intent["quantity"], current_price)

  when "sell"
    if current_price < intent["min_price"]
      notify_skipped_intent(intent, current_price)
      return :skipped
    end
    # Execute sale - affects price_deltas (lowers price)
    execute_sell(ship, system, intent["commodity"], intent["quantity"], current_price)
  end
end

def execute_buy(ship, system, commodity, quantity, price)
  ActiveRecord::Base.transaction do
    ship.user.update!(credits: ship.user.credits - (price * quantity))
    ship.add_cargo!(commodity, quantity)
    PriceDelta.simulate_buy(system, commodity, quantity)  # Same as manual!
  end
end
```

### With System Visits

```ruby
# In SystemVisit or navigation logic
def record_visit(user, system)
  visit = SystemVisit.find_or_initialize_by(user: user, system: system)

  # Snapshot current prices for Fog of War
  visit.price_snapshot = system.current_prices
  visit.last_visit_at = Time.current
  visit.visit_count = (visit.visit_count || 0) + 1
  visit.save!
end
```

### With Procedural Generation

```ruby
# In ProceduralGeneration::SystemGenerator
def generate_base_prices(seed)
  commodities = determine_commodities(seed)

  commodities.each_with_object({}) do |commodity, prices|
    base = COMMODITY_BASE_PRICES[commodity]
    variance = extract_variance(seed, commodity) # -20% to +20%
    prices[commodity] = (base * (1 + variance / 100.0)).round
  end
end

COMMODITY_BASE_PRICES = {
  "ore" => 50,
  "water" => 30,
  "fuel" => 100,
  "food" => 25,
  "electronics" => 200,
  "medicine" => 150,
  "luxury_goods" => 500,
  "construction_materials" => 75
}.freeze
```

## Success Criteria

### Done when:
- [ ] Market prices generated procedurally from system seed
- [ ] Price deltas applied correctly (buy increases, sell decreases)
- [ ] Market Fog of War shows stale prices for unvisited systems
- [ ] Live prices shown when player has active presence
- [ ] Market inventory depletes on buy, restocks over time
- [ ] Buy/sell spread calculated correctly (10% markup/discount)
- [ ] System owners trade at base price (no spread)
- [ ] System owners receive tax on transactions
- [ ] Keyboard navigation (j/k/b/s) functional
- [ ] Price trends displayed based on delta direction
- [ ] Automated route ships use the same marketplace (shared price deltas)
- [ ] Inactive systems (30 days) trigger seizure warnings
- [ ] System auctions run and finalize correctly
- [ ] Owner visit cancels auction and reclaims system

### Measured by:
| Metric | Target | Verify |
|--------|--------|--------|
| Market load time | <50ms | `Benchmark.measure { MarketController#index }` |
| Price determinism | 100% | Same seed = same base prices |
| Fog of War | Enforced | Cannot view market without visit |
| Transaction integrity | 100% | Credits + cargo balance after transaction |

### Fails if:
- Players can see market prices without visiting the system
- Base prices differ between calls for same system
- Transactions can result in negative credits or invalid cargo
- Price deltas cause prices to go below 1 credit
- Buying doesn't increase price or selling doesn't decrease price
- System owner pays the spread (should trade at base price)
- Auction proceeds go anywhere other than burned (should be pure sink)
- Owner can bid on their own seized system (should visit to reclaim instead)
- System seized without all warning messages sent

### Verify with:
```ruby
# Price determinism
bin/rails runner "100.times { raise unless System.peek(x: 1, y: 2, z: 3)[:base_prices] == System.peek(x: 1, y: 2, z: 3)[:base_prices] }"

# Fog of War enforcement
bin/rails test test/controllers/market_controller_test.rb

# Transaction integrity
bin/rails test test/models/market_transaction_test.rb

# Price delta behavior
bin/rails test test/models/price_delta_test.rb

# Owner trading at base price
bin/rails test test/models/system_ownership_test.rb

# Seizure and auction flow
bin/rails test test/jobs/system_ownership_check_job_test.rb

# Owner reclaim cancels auction
bin/rails test test/models/system_auction_test.rb
```

## Implementation Phases

### Phase 1: Procedural Market Data
1. Update `MarketController#generate_market_data` to use `system.base_prices`
2. Apply `PriceDelta` to calculate current prices
3. Calculate buy/sell spread

### Phase 2: Market Fog of War
1. Add `price_snapshot` column to `system_visits`
2. Implement staleness display in view
3. Snapshot prices on visit

### Phase 3: Market Inventory
1. Create `market_inventories` table and model
2. Initialize inventory from procedural generation
3. Add restock background job

### Phase 4: Price Dynamics
1. Implement delta decay job
2. Add trend calculation
3. Display trends in UI

### Phase 5: System Ownership
1. Update `StarbaseAdministrationHub` model with owner tracking
2. Implement owner tax calculation on transactions
3. Implement owner spread bypass (trade at base price)
4. Add `owner_last_visit_at` tracking

### Phase 6: Seizure & Auctions
1. Create `SystemAuction` and `SystemAuctionBid` models
2. Implement `SystemOwnershipCheckJob` for inactivity monitoring
3. Create auction UI (view systems, place bids)
4. Implement auction finalization (winner takes ownership, bids burned)
5. Add seizure warning inbox messages

### Phase 7: NPC Pirates (Optional/Later)
1. Define hazard levels per system (procedural)
2. Implement `PirateEncounterJob` on travel completion
3. Balance encounter rates and outcomes
4. Integrate Marine NPC skill into outcomes

## Notes

- The 10% buy/sell spread may need tuning based on playtesting
- Delta decay rate (5%/hour) creates ~14 hour half-life for prices
- Consider adding "market events" that cause sudden price shifts
- Luxury goods should have higher spreads in developed systems
- The Cradle (0,0,0) should have stable, low-margin markets for training
- **No player-vs-player combat** - all PvP is economic (price manipulation, auction bidding)
- NPC pirates provide the danger/sink that combat would have provided
- System ownership is contested via inactivity auctions, not military takeover

## PvP: Economic Warfare

**Automated routes use the same marketplace system.** This creates emergent PvP opportunities:

### Route Disruption Tactics
1. **Price Spiking:** Observe a competitor's buy route, then buy up the commodity first to raise prices above their `max_price` limit → route skips the intent
2. **Price Dumping:** Sell large quantities to crash prices below their `min_price` → their sell intents get skipped
3. **Inventory Exhaustion:** Buy out market stock before their automated ship arrives
4. **Information Warfare:** Scout competitor routes by observing their ships' patterns, then target those specific markets

### Defense Strategies
1. **Price Limit Buffers:** Set generous limits to absorb manipulation
2. **Route Diversification:** Multiple routes across different systems
3. **Active Monitoring:** Watch for unusual price movements via Inbox alerts
4. **Counter-Trading:** If someone spikes prices, sell into the spike for profit

### Design Implications
- Route execution must use real-time prices (no caching)
- All transactions (manual and automated) affect the same `price_deltas`
- Players can see price trends but not who caused them (unless they observe ships)
- High-traffic systems will have more volatile prices

## System Ownership & Taxation

**No PvP combat.** Systems are contested economically, not militarily. Ownership provides tax revenue and trading advantages.

### The Starbase Administration Hub

From PRD Section 5.3.2:
- **Limit:** Max 1 per star system
- **Cost:** Expensive (Construction Drones + T2 Minerals)
- **Requirement:** Must be staffed by a Governor-class NPC

### Ownership Benefits

**1. Transaction Tax**
The owner receives a percentage of all market transactions in the system:

```ruby
# config/game_constants.rb
SYSTEM_OWNER_TAX_RATE = 0.10  # 10% - configurable for balance tuning
```

Tax is calculated on the spread, not the full transaction:
```
Transaction: Player buys 100 ore at 55 cr (base: 50 cr)
Spread collected: 5 cr × 100 = 500 cr
Owner tax: 500 cr × 10% = 50 cr
```

**2. Reduced Trading Spread**
System owners trade at base prices (no 10% markup/discount):
- Non-owner buys at: `base_price * 1.10`
- Owner buys at: `base_price`
- Non-owner sells at: `base_price * 0.90`
- Owner sells at: `base_price`

This 20% advantage makes ownership valuable for high-volume traders.

**3. Compound Value**
Systems with multiple high-priced minerals are jackpots:
- More commodities = more transaction volume
- Higher prices = larger spreads = more tax revenue
- Discovery of such systems is a major find

### Inactivity & Seizure

Ownership requires active presence (anti-AFK empire design):

**Timeline:**
| Day | Event |
|-----|-------|
| 0 | Owner last visited the system |
| 25 | Inbox: "Your claim on [System] expires in 5 days" |
| 27 | Inbox: "Your claim on [System] expires in 3 days" |
| 29 | Inbox: "Your claim on [System] expires in 1 day" |
| 30 | System seized by Colonial Authority, auction begins |

**The Auction:**
- Colonial Authority lists the system for bidding
- Auction runs for 48 hours (configurable)
- Highest bidder wins
- **All proceeds are burned** (pure money sink)
- Previous owner receives notification when system sells

**Owner Reclaim:**
If the owner visits the system **before the auction ends**, they reclaim it:
- Auction is cancelled
- All bids are refunded
- 30-day timer resets
- Owner is NOT locked out - visiting saves the system

```ruby
# config/game_constants.rb
SYSTEM_OWNERSHIP_INACTIVITY_DAYS = 30
SYSTEM_AUCTION_DURATION_HOURS = 48
SYSTEM_SEIZURE_WARNINGS = [5, 3, 1]  # Days before seizure
```

### Data Model

```ruby
class StarbaseAdministrationHub < Building
  belongs_to :system
  belongs_to :owner, class_name: 'User'

  # Columns: system_id, owner_id, governor_hiring_id,
  #          owner_last_visit_at, seized_at, auction_ends_at

  validates :system_id, uniqueness: true  # Max 1 per system

  def inactive?
    owner_last_visit_at < SYSTEM_OWNERSHIP_INACTIVITY_DAYS.days.ago
  end

  def under_auction?
    seized_at.present? && auction_ends_at > Time.current
  end
end

class SystemAuction < ApplicationRecord
  belongs_to :system
  has_many :bids, class_name: 'SystemAuctionBid'

  # Columns: system_id, started_at, ends_at,
  #          winning_bid_id, previous_owner_id

  def highest_bid
    bids.maximum(:amount)
  end

  def winner
    bids.order(amount: :desc).first&.user
  end
end

class SystemAuctionBid < ApplicationRecord
  belongs_to :auction, class_name: 'SystemAuction'
  belongs_to :user

  # Columns: auction_id, user_id, amount, placed_at
end
```

### Background Jobs

```ruby
class SystemOwnershipCheckJob < ApplicationJob
  queue_as :default

  def perform
    # Check for systems approaching seizure
    StarbaseAdministrationHub.find_each do |hub|
      days_remaining = days_until_seizure(hub)

      if days_remaining <= 0 && !hub.under_auction?
        seize_system(hub)
      elsif SYSTEM_SEIZURE_WARNINGS.include?(days_remaining)
        send_warning(hub, days_remaining)
      end
    end

    # Check for ended auctions
    SystemAuction.where('ends_at < ?', Time.current).pending.find_each do |auction|
      finalize_auction(auction)
    end
  end

  private

  def seize_system(hub)
    hub.update!(seized_at: Time.current, auction_ends_at: SYSTEM_AUCTION_DURATION_HOURS.hours.from_now)
    SystemAuction.create!(system: hub.system, started_at: Time.current, ends_at: hub.auction_ends_at, previous_owner_id: hub.owner_id)
    notify_owner(hub, :seized)
  end

  def finalize_auction(auction)
    winner = auction.winner
    if winner
      auction.system.starbase_administration_hub.update!(owner: winner, owner_last_visit_at: Time.current, seized_at: nil, auction_ends_at: nil)
      # Bids are burned - no transfer to previous owner
      notify_owner(auction.previous_owner, :sold, winner: winner, amount: auction.highest_bid)
    else
      # No bids - system becomes unowned
      auction.system.starbase_administration_hub.destroy!
    end
  end
end
```

## NPC Pirates (Money Sink)

**No player-vs-player combat.** Danger comes from NPC pirates instead.

### Purpose
- Primary money/asset sink
- Creates demand for Marines (NPC class)
- Makes travel risky (can't fully AFK)
- Krog ships retain identity (better pirate survival)
- Encourages warp gate infrastructure (safer travel)

### Encounter Mechanics

```ruby
class PirateEncounterJob < ApplicationJob
  # Runs when ship completes a travel segment

  def perform(ship)
    return if ship.in_safe_zone?  # The Cradle, warp gates

    encounter_chance = calculate_encounter_chance(ship)
    return unless rand < encounter_chance

    outcome = resolve_encounter(ship)
    notify_player(ship, outcome)
  end

  private

  def calculate_encounter_chance(ship)
    base_chance = ship.current_system.hazard_level / 1000.0  # 0-10%
    marine_modifier = 1.0 - (ship.marine_skill * 0.005)      # Marines reduce chance
    base_chance * marine_modifier
  end

  def resolve_encounter(ship)
    # Marines improve outcomes
    marine_roll = ship.marine_skill + rand(1..100)

    if marine_roll > 150
      { result: :repelled, cargo_lost: 0, damage: 0 }
    elsif marine_roll > 100
      { result: :escaped, cargo_lost: rand(5..15), damage: rand(5..10) }
    elsif marine_roll > 50
      { result: :raided, cargo_lost: rand(20..40), damage: rand(15..30) }
    else
      { result: :devastated, cargo_lost: rand(50..80), damage: rand(40..60) }
    end
  end
end
```

### Racial Implications
- **Krog ships:** Higher hull points = survive more damage
- **Vex ships:** Hidden compartments = some cargo protected from raids
- **Solari ships:** Better sensors = can sometimes avoid encounters entirely
- **Myrmidon ships:** Cheap to replace when destroyed
