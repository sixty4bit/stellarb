# StellArb: Current State PRD
*Generated: February 6, 2026*

> A text-based MMO strategy game where players manage automated fleets, trade commodities, and build infrastructure in a procedurally generated galaxy.

---

## 1. Executive Summary

StellArb is a browser-based, text-driven MMO that combines the trading mechanics of *Dope Wars* with the economic depth of *Eve Online*. Players progress through a tutorial system, then graduate to an open galaxy where they trade, explore, hire crew, and build infrastructure.

**Technical Stack:**
- Rails 8.1 (PostgreSQL)
- SolidQueue for background jobs
- Turbo Streams for real-time updates
- Terminal aesthetic (blue-900 backgrounds, orange-500 accents)

---

## 2. The Galaxy

### 2.1 Coordinate System
- **Scale:** 1,000,000 × 1,000,000 × 1,000,000 grid (10^18 possible locations)
- **Generation:** Deterministic procedural generation via coordinate hash
- **Persistence:** Systems are created on first discovery, then stored permanently

### 2.2 The Cradle (0, 0, 0)
- Starting location for all new players
- Tutorial zone with fixed, safe properties
- Saturated markets with low profit margins (by design)

### 2.3 System Properties
Each system has procedurally generated:
- **Star type** (yellow dwarf, red giant, neutron star, etc.)
- **Planet count** (determines resource nodes)
- **Hazard level** (0-100%)
- **Mineral distribution** (per-planet resources with abundance levels)
- **Base prices** (seed-derived market prices)

### 2.4 Exploration
Players can explore the galaxy using three methods:
- **Single direction** — Explore in a specific cardinal direction
- **Growing arcs** — Expand outward in sweeping arcs
- **Orbital** — Explore rings at increasing distances from current position

Discovered coordinates are tracked per-player via `ExploredCoordinate` records.

---

## 3. Tutorial Phases

### 3.1 Phase 1: The Cradle
- **Objective:** Establish a profitable automated trade route
- **Completion:** Route with `status: active` and `total_profit > 0`
- **Reward:** Advancement to Proving Ground

### 3.2 Phase 2: Proving Ground (Talos Arm)
- **Location:** 4 reserved tutorial systems near The Cradle
- **Objective:** Learn exploration and construction mechanics
- **Completion:** Earn the "Colonial Ticket"

### 3.3 Phase 3: Emigration
- **The Choice:** Select from 5 certified Player Hubs
- **The Drop:** Instant teleportation to chosen hub
- **Effect:** All ships relocated, `tutorial_phase: graduated`, `emigrated: true`

---

## 4. Ships

### 4.1 Hull Sizes
| Hull | Base Cost | Description |
|------|-----------|-------------|
| Scout | 500 cr | Fast, small cargo |
| Frigate | 1,500 cr | Light combat |
| Transport | 3,000 cr | Cargo hauler |
| Cruiser | 7,500 cr | Battle cruiser |
| Titan | 20,000 cr | Capital ship |

### 4.2 Races (Factions)
| Race | Bonus | Cost Modifier |
|------|-------|---------------|
| Vex | +20% cargo | 1.0× |
| Solari | +20% sensors | 1.1× |
| Krog | +20% hull | 1.15× |
| Myrmidon | -20% maintenance | 0.9× |

### 4.3 Ship Attributes
- **Cargo capacity** — Units of goods that can be carried
- **Fuel efficiency** — Fuel consumed per unit distance
- **Maneuverability** — Speed multiplier for travel time
- **Hardpoints** — Weapon mount slots
- **Hull points** — Damage capacity
- **Sensor range** — Scan distance

### 4.4 Ship Systems

**Travel:**
- Conventional travel consumes fuel based on distance × efficiency
- Travel time based on distance / (speed × maneuverability)
- Ships arrive via `ShipArrivalJob` (runs every minute)

**Warp Travel:**
- Instant travel via warp gates (flat 5 fuel cost)
- Requires connected warp gate network

**Refueling:**
- Ships refuel at current system's market
- Price = base fuel price + any price deltas

**Upgrades:**
- Each attribute can be upgraded (cost scales with level)
- Max upgrades per attribute based on hull size (3-8)

**Cargo:**
- Add/remove commodities to ship cargo
- Cargo capacity limits total weight

---

## 5. Trading & Economy

### 5.1 Price Model (Static + Dynamic)
```
Final Price = Base Price × Abundance Modifier × Π(Building Modifiers) + Price Delta
```

- **Base Price:** Procedurally generated per system (stored in `properties.base_prices`)
- **Abundance Modifier:** 0.7× (very high) to 1.5× (very low) based on local mineral distribution
- **Building Modifiers:** Mines reduce prices, factories affect input/output prices
- **Price Delta:** Database-stored adjustments from market activity

### 5.2 Market Operations
- Trading requires an operational **Marketplace** (civic building) in the system
- **Buy:** Remove from market inventory, add to ship cargo, deduct credits
- **Sell:** Add to market inventory, remove from ship cargo, add credits
- Marketplace fee applied (5% at T1 → 1% at T5)

### 5.3 Market Inventory
- Each system has `MarketInventory` records per commodity
- `MarketRestockJob` runs hourly to replenish stock
- Restock rate affected by warehouse tier

---

## 6. Minerals & Components

### 6.1 Minerals (60 total)

**Tier 1 — Common (10):** Iron, Copper, Aluminum, Silicon, Carbon, Sulfur, Limestoneite, Salt, Coal, Graphite

**Tier 2 — Uncommon (15):** Nickel, Zinc, Tin, Lead, Manganese, Chromium, Cobalt, Tungsten, Molybdenum, Vanadium, Quartz, Feldspar, Mica, Bauxite, Magnetite

**Tier 3 — Rare (15):** Gold, Silver, Platinum, Palladium, Rhodium, Titanium, Lithium, Beryllium, Tantalum, Niobium, Gallium, Germanium, Indium, Tellurium, Neodymium

**Tier 4 — Exotic (10):** Uranium, Thorium, Plutonium, Iridium, Osmium, Rhenium, Scandium, Yttrium, Hafnium, Zirconium

**Futuristic (10):** Stellarium (Neutron Stars), Voidite (Black Holes), Chronite (Binary Systems), Plasmaite (Blue Giants), Darkstone (Deep Space), Quantium (Pulsars), Nebulite (Nebulae), Solarite (Yellow Giants), Cryonite (Ice Giants), Exotite (Anomalies)

### 6.2 Mineral Discovery
- Futuristic minerals require discovery before appearing in markets
- Discovery tracked via `MineralDiscovery` records
- Each tied to specific star/system types

### 6.3 Components (45 total, 9 categories)
Components are manufactured from minerals at factories:

| Category | Example Components |
|----------|-------------------|
| Basic Materials | Iron Plate, Copper Wire, Steel Beam, Metal Bracket, Carbon Rod |
| Electronics | Circuit Board, Processor, Sensor, Memory Core, Power Regulator |
| Structural | Hull Plating, Bulkhead, Frame Section, Reinforced Panel, Pressure Seal |
| Power Systems | Battery, Fusion Cell, Solar Panel, Power Conduit, Reactor Core |
| Propulsion | Thruster, Engine Core, FTL Coil, Fuel Injector, Nav Computer |
| Weapons | Laser Lens, Missile Casing, Railgun Barrel, Plasma Chamber, Targeting Array |
| Defense | Shield Emitter, Armor Plate, Deflector Array, Point Defense, Stealth Plating |
| Advanced Tech | Quantum Core, Gravity Generator, Temporal Stabilizer, Dark Matter Container, Exo-Research Module |

**Component Pricing:** `base_price = Σ(input_mineral_prices × quantities) × 1.5`

### 6.4 Factory Specializations (8 types)
| Specialization | Consumes | Produces |
|----------------|----------|----------|
| Basic | Iron, Copper, Carbon, Aluminum, Graphite | Basic Materials |
| Electronics | Silicon, Copper, Gold, Quartz, Germanium | Electronics |
| Structural | Iron, Titanium, Carbon | Structural |
| Power | Lithium, Uranium, Cobalt, etc. | Power Systems |
| Propulsion | Titanium, Tungsten, Stellarium, etc. | Propulsion |
| Weapons | Tungsten, Platinum, Quartz, etc. | Weapons |
| Defense | Titanium, Nebulite, Iridium, etc. | Defense |
| Advanced | Quantium, Voidite, Chronite, etc. | Advanced Tech |

---

## 7. Buildings

### 7.1 Building Types

| Function | Name | Purpose |
|----------|------|---------|
| extraction | Mine | Extract minerals, reduce local prices |
| refining | Factory | Convert minerals to components |
| logistics | Warehouse | Increase capacity, trade limits, restock rate |
| civic | Marketplace | Enable trading, reduce fees, increase NPC volume |
| defense | Defense Platform | System defense (not yet implemented) |

### 7.2 Tiers (1-5)

**Mines (Extraction):**
| Tier | Cost | Supply Bonus | Price Effect |
|------|------|--------------|--------------|
| 1 | 10,000 | +20% | -5% |
| 2 | 25,000 | +40% | -10% |
| 3 | 50,000 | +70% | -15% |
| 4 | 100,000 | +100% | -20% |
| 5 | 250,000 | +150% | -25% |

**Warehouses (Logistics):**
| Tier | Cost | Capacity Bonus | Max Trade Size |
|------|------|----------------|----------------|
| 1 | 5,000 | +50% | 500 |
| 2 | 15,000 | +100% | 1,000 |
| 3 | 40,000 | +200% | 2,500 |
| 4 | 100,000 | +400% | 5,000 |
| 5 | 300,000 | +800% | 10,000 |

**Marketplaces (Civic):**
| Tier | Cost | Fee | NPC Volume |
|------|------|-----|------------|
| 1 | 8,000 | 5% | 1× |
| 2 | 20,000 | 4% | 7× |
| 3 | 50,000 | 3% | 13× |
| 4 | 120,000 | 2% | 19× |
| 5 | 300,000 | 1% | 25× |

**Factories (Refining):**
| Tier | Cost | Input Demand | Output Supply |
|------|------|--------------|---------------|
| 1 | 25,000 | +10% | -5% |
| 2 | 60,000 | +15% | -10% |
| 3 | 150,000 | +20% | -15% |
| 4 | 400,000 | +25% | -20% |
| 5 | 1,000,000 | +30% | -25% |

### 7.3 Building Operations
- **Construction:** Instant for now (construction_ends_at exists for future)
- **Upgrades:** Sequential (T1→T2→T3→T4→T5), cost = next tier cost
- **Disable/Enable:** Buildings can be toggled operational status
- **Demolish:** Permanently remove building
- **Repair:** Fix damaged buildings

---

## 8. NPCs (Crew)

### 8.1 The Recruiter
- Shared pool of available recruits per level tier
- Pool refreshes every 30-90 minutes (`RecruiterRefreshJob`)
- All players of same level see same recruits

### 8.2 Recruit Properties
- **Race:** vex, solari, krog, myrmidon
- **Class:** Various specializations
- **Skill:** 1-100 rating
- **Chaos Factor:** Randomness in behavior
- **Lifespan:** Days until retirement/death

### 8.3 Hiring System
- Recruits hired from pool → creates `HiredRecruit` copy
- `Hiring` join table links recruit to assignable (Ship/Building)
- Custom names, wage tracking, termination dates

### 8.4 NPC Lifecycle
- **Age Progression:** `NpcAgeProgressionJob` runs daily at 4am
- **Aging Events:** `NpcAgingJob` runs at 4:05am to handle retirement/death
- Older NPCs may retire or die, requiring replacement

---

## 9. Routes (Automated Trading)

### 9.1 Route Structure
```ruby
{
  name: "Iron Run",
  status: "active",      # active | paused | completed
  stops: [
    { system_id: 1, name: "The Cradle", intents: [...] },
    { system_id: 2, name: "Mining Colony", intents: [...] }
  ],
  loop_count: 42,
  total_profit: 15000,
  profit_per_hour: 625.0
}
```

### 9.2 Intents (Per-Stop Actions)
Each stop can have buy/sell intents with price limits:
```ruby
{ action: "buy", commodity: "Iron", quantity: 100, max_price: 12 }
{ action: "sell", commodity: "Iron", quantity: 100, min_price: 15 }
```

### 9.3 Route Execution
- Ships assigned to routes follow stop sequence
- Execute intents at each stop (buy/sell within limits)
- Track profit per loop, total profit, loops completed

---

## 10. Catastrophe System

### 10.1 Pip Infestations
- **Pips:** Hostile creatures that can infest ships/buildings
- **Spread:** `PipEscalationJob` runs daily to spread infestations
- **Effect:** Infested assets become `disabled`

### 10.2 Incidents
- Tracked via `Incident` model
- Tied to assets (ships/buildings)
- Severity levels affect gameplay
- Resolution clears the incident

### 10.3 Pirate Encounters
- `PirateEncounterJob` runs on ship arrival
- Conventional travel (not warp) may trigger encounters
- Hazard level affects encounter chance

---

## 11. System Ownership & Auctions

### 11.1 System Ownership
- Players can own systems (via `owner_id`)
- Owner inactivity tracked via `owner_last_visit_at`
- `SystemOwnershipCheckJob` runs daily at 2am

### 11.2 Seizure & Auction
- Inactive owners may have systems seized
- Seized systems go to auction
- Players can bid on auctioned systems
- Auctions have pending → active → completed lifecycle

---

## 12. Messaging System

### 12.1 Inbox
- In-game message system for notifications
- Categories: system, travel, quest, discovery
- Urgent flag for priority messages
- Read/unread tracking

### 12.2 Notification Events
- Ship arrivals
- System discoveries (first visits)
- Quest updates
- Welcome messages (on account creation)

---

## 13. UI/UX

### 13.1 Visual Style
- Terminal/CLI aesthetic
- **Colors:** blue-900 backgrounds, orange-500 accents
- Monospace fonts
- Minimal graphics, text-focused

### 13.2 Real-Time Updates
- Turbo Streams for live updates
- Ship arrivals broadcast to user's ships stream
- Client-side countdowns for arrivals

### 13.3 Navigation
- Main menu with keyboard shortcuts
- Systems view for galaxy exploration
- Market view with price breakdowns

### 13.4 Sound Effects
- Audio cues for game events (implemented)

---

## 14. Background Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| ShipArrivalJob | Every minute | Process arriving ships |
| NpcAgeProgressionJob | 4am daily | Increment NPC ages |
| NpcAgingJob | 4:05am daily | Handle retirement/death |
| PipEscalationJob | 3am daily | Spread pip infestations |
| RecruiterRefreshJob | Every hour | Replenish recruit pool |
| MarketRestockJob | Every hour | Restock market inventory |
| SystemOwnershipCheckJob | 2am daily | Check inactivity, run auctions |
| PirateEncounterJob | On arrival | Check for pirate attacks |

---

## 15. Authentication

- Passwordless magic link login (planned)
- Session-based authentication
- Profile setup required after first login

---

## 16. Data Models Summary

| Model | Purpose |
|-------|---------|
| User | Player account, credits, tutorial phase |
| Ship | Player vessels with travel, cargo, crew |
| System | Procedural star systems with properties |
| Building | Player-owned infrastructure |
| Route | Automated trade routes |
| HiredRecruit | Employed NPCs |
| Hiring | NPC ↔ Asset assignments |
| Incident | Catastrophe/damage events |
| Message | In-game notifications |
| PriceDelta | Market price adjustments |
| MarketInventory | System stock levels |
| SystemVisit | Player visit history |
| FlightRecord | Ship movement history |
| ExploredCoordinate | Player exploration tracking |
| MineralDiscovery | Futuristic mineral unlocks |
| WarpGate | System-to-system instant travel |
| PlayerHub | Emigration destinations |
| SystemAuction | Ownership transfer auctions |
| Quest / PlayerQuest | Tutorial objectives |

---

## 17. Test Coverage

- **1,418+ tests** across models, controllers, jobs, and services
- Integration tests preferred over system tests
- TDD workflow: red → green → refactor

---

*This document reflects the implemented state of StellArb as of February 6, 2026.*
