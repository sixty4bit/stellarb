---
title: StellArb ROADMAP
created: 2026-02-04
tags: [stellarb, game-design, roadmap]
---

# **StellArb ROADMAP**
Project Name: Stellar Arbitrage (Working Title)
Version: 1.0 (Consolidated)
Date: February 4, 2026

---

> *You are traveling through space. It's like a maze of twisty passages that look all alike, but that's another game. This game has lasers.*

---


## **1. Executive Summary**
A massive multiplayer online strategy game that bridges the gap between the fast-paced, high-stakes trading of *Dope Wars* and the logistical depth of *Eve Online*, without the "spreadsheet fatigue." The game features a text-based (Command Line Interface) environment where players manage automated fleets, maintain decaying assets, and build infrastructure in a persistent, shared economy.

## **2. The World (Planetary Coordinate Space - PCS)**
* Scale: 1,000,000 x 1,000,000 x 1,000,000 grid (10^18 units).
* Generation: Deterministic Procedural Generation based on coordinate hash. No map data is stored until a player "Discovers" a system.
* The Cradle (System 0,0,0):
  * **Starting Point:** All new players begin here — a fully developed, high-security training zone.
  * **Purpose:** Learn the core mechanics (automation, trading, market chains) in a safe environment.
  * **Limitation:** Saturated markets mean low profits — this is by design to encourage graduation.
* The Frontier: Infinite procedural space beyond the Cradle. Deeper exploration requires larger ships with higher fuel capacity.
* Player Hubs: End-game players build "Spawn Hubs" in the frontier. Graduating players are teleported to these hubs to join established economies (see Section 5.5).
* Visibility:
  * 3D Bubble: Players only see stars within their current fuel range.
  * Fog of War: Unknown sectors are pitch black until scanned or data is purchased.
  * Navigation: Players are provided a list of valid directional commands/vectors based on their ship's capabilities.

### **2.1. Success Criteria**

**Done when:**
- [ ] Generate any coordinate (x,y,z) and get deterministic system properties
- [ ] System at (0,0,0) always returns "The Cradle" with tutorial properties
- [ ] Players can only see systems within their fuel range
- [ ] Fog of War hides unvisited systems completely
- [ ] Navigation shows only reachable destinations

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| Coordinate space | 10^18 unique positions | `assert (0..999_999).size ** 3 == 10**18` |
| Cradle special case | Always at 0,0,0 | `generate_system(0,0,0).name == "The Cradle"` |
| Visibility range | Based on fuel | `visible_systems.all? { \|s\| s.distance <= ship.fuel_range }` |

**Fails if:**
- Player can see systems beyond fuel range
- Unvisited systems show any data (must be pitch black)
- The Cradle is not at coordinates (0,0,0)
- Navigation suggests unreachable destinations

## **3. Core Gameplay Loop (The Career Path)**
The three-phase journey from tutorial to the real game.

### **3.1. Phase 1: The Cradle (The Intern)**
* **Location:** The "Cradle" (System 0,0,0). A fully developed, high-security zone.
* **Objective:** **Prove Competence.**
* **Task:** Establish a basic, automated supply chain (e.g., Haul `Water` to `Hydroponics`).
  * *Constraint:* The market is saturated. Profit margins are razor-thin. This phase is not about getting rich; it is about learning the mechanics of automation and "The Market Chain."
* **Reward:** **"The Grant."** Upon completing the loop, the Colonial Authority provides a lump sum of credits sufficient to purchase a functional Exploration Ship and hire a crew.

### **3.2. Phase 2: The Proving Ground (The Scout)**
* **Objective:** **Learn Exploration & Construction.**
* **Task:** Locate a "Reserved" unexplored system immediately outside the Cradle.
* **Mechanics Introduced:**
  * **Scanning:** How to triangulate signatures and find hidden nodes.
  * **Building:** Constructing the first asset (e.g., a simple Mineral Extractor).
  * **Hiring:** Using the Recruiter to staff that asset.
* **The Gate:** Completing this phase unlocks the **"Colonial Ticket"** (The One-Time Drop).

### **3.3. Phase 3: The Emigration (The Colonist)**
* **The Choice:** The player is presented with dossiers on **5 Remote Systems**.
  * *Selection Logic:* These are highly developed "Player Hubs" located deep in the frontier.
  * *Data Provided:* Local resource prices, security rating, owning Guild/Player name.
  * *Constraint:* Players cannot see the full map; they can only see these 5 specific "Immigration Options."
* **The Drop:** The player selects one destination and is **instantly transported** there with their starter ship and capital.
* **The Real Game:**
  * The player is now thousands of light years from the Cradle.
  * **Goal:** Explore the *local neighborhood* of this new hub, find fresh resource nodes, and connect them to the Hub's economy via new Market Chains.

### **3.4. Success Criteria**

**Done when:**
- [ ] New player spawns in The Cradle (0,0,0)
- [ ] Tutorial quest teaches basic supply chain automation
- [ ] Completing Phase 1 grants enough credits for exploration ship
- [ ] Phase 2 introduces scanning and construction mechanics
- [ ] Phase 3 presents exactly 5 remote hub options
- [ ] Player is instantly transported to chosen hub
- [ ] Cannot return to Cradle after emigration

**Measured by:**
| Phase | Completion Trigger | Reward |
|-------|-------------------|---------|
| Phase 1 | First profitable automated route | "The Grant" (10,000 credits) |
| Phase 2 | First building constructed | "Colonial Ticket" unlock |
| Phase 3 | Hub selection made | Instant transport to frontier |

**Fails if:**
- Player can skip tutorial phases
- Grant money insufficient for basic exploration ship
- Player can see more than 5 hub options
- Player can travel back to Cradle after emigration
- Tutorial doesn't teach all core mechanics

## **4. The Economy & Resources**

### **4.1. The "Static + Dynamic" Model**
* Base Price: Calculated mathematically via Seed.
* Price Delta: The only data stored in DB. Tracks inventory shifts.

### **4.2. Minerals (The Building Blocks)**
* Function: Used to construct Buildings and Ships.
* Distribution: Planets have specific mineral profiles. Starter galaxies have abundant "Basic" minerals.

### **4.3. NPCs (The Human Resource)**
* Definition: NPCs are a resource, governed like minerals. They are required to operate Ships and Buildings.
* Recruitment:
  * **The Recruiter:** A rotating list of available NPCs, refreshed at random intervals (30-90 minutes).
  * **Shared Pool:** All players of the same level see the **same recruits**. No per-player generation.
  * **Scarcity:** High-level NPCs (Specialists) appear rarely in the Recruiter's list and are essential for advanced assets.
* Lifecycle:
  * **Decay:** NPCs age, retire, or die, requiring constant replenishment.
  * **Wage Demands:** Higher skill NPCs demand exponentially higher wages (see 4.4.3).

#### **4.3.1. Recruiter Database Schema**

```ruby
class Recruit < ApplicationRecord
  # Shared pool - all players of same level see same recruits
  # Columns: level_tier, race, npc_class, skill, base_stats (jsonb),
  #          employment_history (jsonb), chaos_factor, available_at, expires_at
  
  scope :available_for, ->(user) { where(level_tier: user.level_tier).where("available_at <= ? AND expires_at > ?", Time.current, Time.current) }
end

class HiredRecruit < ApplicationRecord
  # Immutable copy created when player hires from pool
  # Columns: original_recruit_id, race, npc_class, skill, stats (jsonb),
  #          employment_history (jsonb), chaos_factor
  
  has_many :hirings
  has_many :users, through: :hirings
end

class Hiring < ApplicationRecord
  # Player's relationship to their hired recruits
  # Columns: user_id, hired_recruit_id, custom_name, assignable_type,
  #          assignable_id, hired_at, wage, status, terminated_at
  
  belongs_to :user
  belongs_to :hired_recruit
  belongs_to :assignable, polymorphic: true  # Ship or Building
  
  enum :status, { active: "active", fired: "fired", deceased: "deceased", retired: "retired", striking: "striking" }
end

class Ship < ApplicationRecord
  has_many :hirings, as: :assignable
  has_many :crew, through: :hirings, source: :hired_recruit
end

class Building < ApplicationRecord
  has_many :hirings, as: :assignable
  has_many :staff, through: :hirings, source: :hired_recruit
end
```

### **4.4. NPC Mechanics (Human Resources)**
NPCs are the "Software" that runs the "Hardware" (Ships/Buildings). They are a finite, decaying resource that directly impacts the mathematical efficiency of assets.

#### **4.4.1. Classes & Roles**
* **The Governor (Admin):** Assigned to Habitats/Factories.
  * *RNG Effect:* Determines the **Tax Yield Variance**. A bad governor "skims" off the top (lower income). A good governor finds "Tax Loopholes" (bonus income).
* **The Navigator (Pilot):** Assigned to Ships.
  * *RNG Effect:* Determines **Fuel Efficiency** and **Event Avoidance**. A good navigator can bypass a "Nebula Storm" event; a bad one gets stuck in it.
* **The Engineer (Tech):** Assigned to any asset with a "Maintenance" stat.
  * *RNG Effect:* Modifies the **Breakdown Tick**.
  * *Formula:* `Breakdown_Chance = Base_Rate / (Engineer_Skill * 0.5)`.
  * *Result:* A high-tier engineer can keep a rusty, cheap ship running indefinitely.
* **The Marine (Security):** Assigned to anti-piracy assets.
  * *RNG Effect:* Modifies **Combat Rolls** and **Theft Protection**.

#### **4.4.2. Quality & Traits**
* **Generation:** NPCs are generated with a "Rarity Tier" (Common, Uncommon, Rare, Legendary).
* **Traits:** Procedurally assigned "Quirks" that add risk/reward.
  * *Example (Trait: "Gambler"):* The NPC might randomly generate huge profits one week, then drain the account the next.
  * *Example (Trait: "Cultist"):* The NPC works for free but lowers the "Stability" of the planet.

#### **4.4.3. Management & Decay**
* **The Wage Spiral:** Higher skill NPCs demand exponentially higher wages. If you fail to pay, they don't just leave—they sabotage.
* **Aging:** NPCs have a functional lifespan. A "Legendary Admiral" will eventually retire, forcing the player to scramble to find a replacement or watch their fleet efficiency plummet.
* **Poaching:** Players can attempt to hire NPCs away from other players by offering higher wages (Market PvP).

### **4.5. Success Criteria**

**Done when:**
- [ ] Base prices generated from system seed (no DB lookup)
- [ ] Only price deltas stored in database
- [ ] Minerals have specific planetary distribution patterns
- [ ] NPCs appear in shared Recruiter pool by level tier
- [ ] All players of same level see identical recruits
- [ ] NPCs age and can retire/die
- [ ] Wages scale exponentially with skill level

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| Price calculation | Pure function | `base_price(seed) + delta_from_db` |
| Recruiter pool | Shared by level | `Recruit.available_for(user1) == Recruit.available_for(user2)` |
| NPC decay | Age increases daily | `npc.age_days > 0 after 24 hours` |
| Wage scaling | Exponential | `skill_90_wage > skill_80_wage * 1.5` |

**Fails if:**
- Base prices require database lookup
- Different players see different recruits at same level
- NPCs don't age or decay
- Linear wage scaling (should be exponential)

## **5. Infrastructure & Assets**

### **5.1. Procedural Generation Engine**

The universe, assets, and NPCs are generated deterministically from coordinate seeds — not stored until "realized" by player action.

#### **5.1.1. Core Principles**
* **Deterministic:** Same seed → same output, always. No randomness at generation time.
* **Lazy Realization:** Nothing exists in the database until a player discovers it.
* **Attribute-Based:** Assets are combinations of attributes, not hand-crafted designs.

#### **5.1.2. System Generation**
* **Input:** 3D coordinate tuple `(x, y, z)` where each axis is `0..999,999`
* **Seed Formula:** `SHA256(x || y || z)` → 256-bit seed (64 hex characters)
* **Output:** Deterministic system properties:
  * Star type (enum: Red Dwarf, Yellow, Blue Giant, etc.)
  * Planet count (0-12)
  * Resource distribution (mineral types + quantities)
  * Base market prices
  * Hazard level (0-100)

**Seed Extraction Algorithm:**
```ruby
def extract_from_seed(seed_hex, byte_offset, byte_length, max_value)
  # seed_hex is 64 chars (256 bits), each char = 4 bits
  slice = seed_hex[byte_offset * 2, byte_length * 2]
  slice.to_i(16) % max_value
end

# Example: generate_system(100, 200, 300)
seed = Digest::SHA256.hexdigest("100|200|300")
# => "a1b2c3d4e5f6..." (64 hex chars)

# Byte allocations (non-overlapping):
star_type_idx  = extract_from_seed(seed, 0, 2, STAR_TYPES.length)   # bytes 0-1
planet_count   = extract_from_seed(seed, 2, 1, 13)                   # byte 2 (0-12)
hazard_level   = extract_from_seed(seed, 3, 1, 101)                  # byte 3 (0-100)
mineral_seed   = extract_from_seed(seed, 4, 4, 2**32)                # bytes 4-7
price_seed     = extract_from_seed(seed, 8, 4, 2**32)                # bytes 8-11
# ... remaining 20 bytes available for future expansion
```

**Star Types:**
```ruby
STAR_TYPES = %w[
  red_dwarf yellow_dwarf orange_dwarf white_dwarf
  blue_giant red_giant yellow_giant
  neutron_star binary_system black_hole_proximity
].freeze
```

#### **5.1.3. Ship Generation**
* **Blueprint Pool:** Grows dynamically as player base increases.
* **Input:** Race + Hull Size + Variant Index + Location Seed
* **Variation:** A "Mark IV Hauler" in Galaxy A has different stats than one in Galaxy B (seed includes location).

**Hull Sizes & Base Scaling:**
```ruby
HULL_SIZES = {
  scout:     { cargo: 10,   fuel_eff: 1.0, crew: 1..2,  hardpoints: 1 },
  frigate:   { cargo: 50,   fuel_eff: 1.2, crew: 2..4,  hardpoints: 2 },
  transport: { cargo: 200,  fuel_eff: 1.5, crew: 3..6,  hardpoints: 2 },
  cruiser:   { cargo: 500,  fuel_eff: 1.8, crew: 5..10, hardpoints: 4 },
  titan:     { cargo: 2000, fuel_eff: 2.0, crew: 10..20, hardpoints: 8 }
}.freeze
```

**Attribute Generation:**
```ruby
def generate_ship(race, hull_size, variant_idx, location_seed)
  base = HULL_SIZES[hull_size]
  seed = Digest::SHA256.hexdigest("#{race}|#{hull_size}|#{variant_idx}|#{location_seed}")
  
  # Cargo scales with size (base ± 20%)
  cargo_variance = extract_from_seed(seed, 0, 2, 41) - 20  # -20 to +20
  cargo = (base[:cargo] * (1 + cargo_variance / 100.0)).round
  
  # Fuel efficiency: better with size, ±15% variance
  fuel_variance = extract_from_seed(seed, 2, 2, 31) - 15   # -15 to +15
  fuel_efficiency = (base[:fuel_eff] * (1 + fuel_variance / 100.0)).round(2)
  
  # Apply racial bonuses (see Section 10)
  # ...
end
```

**Ship Attributes (all ships have these):**
| Attribute | Unit | Scales With |
|-----------|------|-------------|
| Cargo Capacity | tons | Hull size (base ± 20%) |
| Fuel Efficiency | units/grid | Hull size (base ± 15%) |
| Maneuverability | 1-100 | Inverse of hull size |
| Hardpoints | slots | Hull size |
| Crew Slots | min..max | Hull size |
| Maintenance Rate | credits/day | Hull size × quality |
| Hull Points | HP | Hull size |
| Sensor Range | grids | Race bonus + variant |

#### **5.1.4. Building Generation**
* **Input:** Race + Function + Tier + Location Seed
* **Attributes (all buildings have these):**
  * NPC Staff Slots (min/max)
  * Maintenance Rate (credits/day)
  * Hardpoints (defense slots)
  * Storage Capacity (tons)
  * Output Rate (units/hour)
  * Power Consumption (energy/hour)
  * Durability (hit points)

#### **5.1.5. NPC Generation (Pool Generation)**
NPCs are generated for the **shared Recruiter pool**, not per-player. See Section 4.3.1 for schema.

* **Input:** Level tier + rotation timestamp + slot index
* **Output:**
  * Name (from pre-generated name pool, see below)
  * Race (Vex, Solari, Krog, Myrmidon)
  * Class (Governor, Navigator, Engineer, Marine)
  * Skill level (1-100)
  * Rarity tier (Common 70%, Uncommon 20%, Rare 8%, Legendary 2%)
  * Quirks (1-3 traits, determined by Chaos Factor)
  * Hidden Chaos Factor (0-100, never shown to player)
  * Employment History (see 5.1.6)
* **Pool Size:** Based on `(active_players * 0.3)` per class, minimum 10 per class.
* **Rotation:** New recruits generated every 30-90 minutes (random per level tier).

**NPC Classes:**
| Class | Assigned To | Effect |
|-------|-------------|--------|
| Governor | Habitats, Factories | Tax yield variance |
| Navigator | Ships | Fuel efficiency, event avoidance |
| Engineer | Any asset w/ maintenance | Breakdown chance reduction |
| Marine | Defense assets | Combat rolls, theft protection |

**Quirks (Chaos Factor Driven):**
Quirks are personality traits that affect NPC performance. Higher Chaos Factor = more disruptive quirks.

```ruby
# Quirk count based on Chaos Factor
quirk_count = case chaos_factor
  when 0..20   then rand(0..1)   # 0-1 quirks, mostly positive
  when 21..50  then rand(1..2)   # 1-2 quirks, mixed
  when 51..80  then rand(1..2)   # 1-2 quirks, mostly negative
  when 81..100 then rand(2..3)   # 2-3 quirks, mostly negative
end

# Quirk pools (expand these with procedural generation later)
POSITIVE_QUIRKS = %w[meticulous efficient loyal frugal lucky]
NEUTRAL_QUIRKS = %w[superstitious nocturnal chatty loner gambler]
NEGATIVE_QUIRKS = %w[lazy greedy volatile reckless paranoid saboteur]

# Selection weighted by chaos factor
# Low chaos: 70% positive, 25% neutral, 5% negative
# High chaos: 5% positive, 25% neutral, 70% negative
```

**Name Generation:**
Names are pulled from a pre-generated pool of ~1000 funny sci-fi names stored in `db/seeds/npc_names.yml`. Names are race-tagged for flavor.

```yaml
# db/seeds/npc_names.yml
vex:
  - "Grimbly Skunt"
  - "Fleezo Margin"
  - "Krix Bottomline"
solari:
  - "7-Alpha-Null"
  - "Research Unit Zed"
  - "Calculus Prime"
krog:
  - "Smashgut Ironface"
  - "Bork the Unpleasant"
  - "Captain Dents"
myrmidon:
  - "Cluster 447"
  - "The Swarm That Hums"
  - "Unit Formerly Known As 12"
```

#### **5.1.6. NPC Employment History (The Resume)**
Every NPC comes with a procedurally generated work history. This is the player's only clue to the hidden Chaos Factor.

* **Input:** NPC seed + Chaos Factor
* **Output:** 2-5 prior employment records

**Record Structure:**
```
[Employer Name] — [Duration] — [Outcome]
```

**Outcome Generation (weighted by Chaos Factor):**
| Chaos Factor | "Clean Exit" % | "Incident" % | "Catastrophe" % |
|--------------|----------------|--------------|-----------------|
| 0-20 | 90% | 10% | 0% |
| 21-50 | 70% | 25% | 5% |
| 51-80 | 40% | 45% | 15% |
| 81-100 | 10% | 50% | 40% |

**Example Resumes:**

*Low Chaos (Safe Hire):*
```
Eng. Yara (Solari) — Skill: 72
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Prior Employment:
• Stellaris Corp — 14 months — Contract completed
• Frontier Mining Co — 8 months — Promoted to Lead
• Void Runners LLC — 22 months — Company dissolved (economic)
```

*High Chaos (Red Flags):*
```
Eng. Zorg (Krog) — Skill: 91
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Prior Employment:
• Titan Haulers — 2 months — "Creative differences"
• DeepCore Mining — 6 months — Reactor incident (T4)
• Freeport Station — 1 month — Mutual separation
• Unlisted (gap) — 8 months
```

**Red Flag Signals (learnable patterns):**
* Short tenures (<3 months)
* Vague exit reasons ("creative differences", "mutual separation")
* Employment gaps ("Unlisted")
* Incident mentions with severity tier
* Multiple employers in short timespan
* "Reactor incident" / "cargo loss" / "navigation error"

**The Skill:**
High-skill NPCs with clean histories are rare and expensive. Players must decide: *Is a Skill-91 Engineer with two "incidents" worth the risk over a Skill-65 Engineer with a spotless record?*

#### **5.1.7. Success Criteria**

**Done when:**
- [ ] `generate_system(x, y, z)` returns identical output on every call
- [ ] `generate_system(0, 0, 0)` returns "The Cradle" with fixed tutorial properties
- [ ] System generation completes in <15ms
- [ ] Ship generation completes in <10ms
- [ ] Building generation completes in <10ms
- [ ] NPC pool rotation completes in <500ms (batch job, not per-request)
- [ ] Recruiter query returns in <5ms (indexed lookup, no generation)
- [ ] No database reads required for system/asset generation (pure function)
- [ ] 1 million unique coordinates produce 1 million unique systems (collision test)

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| System generation | <15ms | `Benchmark.measure { generate_system(rand, rand, rand) }` |
| Ship generation | <10ms | `Benchmark.measure { generate_ship(seed) }` |
| Building generation | <10ms | `Benchmark.measure { generate_building(seed) }` |
| NPC pool rotation (100 NPCs) | <500ms | `Benchmark.measure { RecruiterPool.rotate!(tier: 1) }` |
| Recruiter query | <5ms | `Benchmark.measure { Recruit.available_for(user) }` |
| Determinism | 100% | `1000.times { assert_equal generate_system(x,y,z), generate_system(x,y,z) }` |
| Collision rate | 0% | Hash 10^6 coords, check for duplicate seeds |

**Fails if:**
- Same coordinates produce different results on different calls
- Same coordinates produce different results on different servers
- System/asset generation requires database lookup (breaks offline/testing)
- Cradle (0,0,0) is not special-cased for tutorial
- Recruiter shows different NPCs to players of the same level tier
- Hired recruit stats differ from original recruit stats (copy failure)
- Generation time exceeds 50ms for any single item (blocks UI)

**Racial Integrity Checks (from Section 10):**
- [ ] Vex ships average 20% higher Cargo Capacity than global mean
- [ ] Solari ships average 20% higher Sensor Range than global mean
- [ ] Krog ships average 20% higher Hull Points than global mean
- [ ] Myrmidon ships average 20% lower Cost than global mean

**Recruiter Schema Checks:**
- [ ] All players of same level see identical recruit list
- [ ] `hired_recruits` row matches source `recruits` row exactly
- [ ] `hirings.assignable` polymorphic works for both Ship and Building
- [ ] Pool rotation doesn't affect already-hired recruits

**Verify with:**
```ruby
# Run the generation test suite
bin/rails test test/lib/procedural_generation_test.rb

# Verify racial balance
bin/rails runner "ProceduralGeneration.audit_racial_balance"

# Stress test determinism
bin/rails runner "ProceduralGeneration.determinism_check(iterations: 10_000)"

# Verify recruiter consistency
bin/rails test test/models/recruiter_pool_test.rb

# Verify hire-copy integrity
bin/rails runner "HiredRecruit.verify_copy_integrity!"
```

### **5.2. Building Ecosystem**
* Function: Buildings provide passive income, storage, or resource processing.
* Messaging: Buildings send status reports ("Storage Full", "Worker Strike", "Machinery Broken") to the player's Inbox.

#### **5.2.1. Building Types & Functions**

**Resource Extraction:**
```ruby
EXTRACTORS = {
  mineral_mine: {
    inputs: { energy: 10 },
    outputs: { minerals: 20 },
    staff: { engineer: 1, marine: 1 },
    planet_requirement: :rocky,
    tiers: 1..5
  },
  gas_harvester: {
    inputs: { energy: 15 },
    outputs: { gas: 30 },
    staff: { engineer: 2 },
    planet_requirement: :gas_giant,
    tiers: 1..5
  },
  water_extractor: {
    inputs: { energy: 5 },
    outputs: { water: 50 },
    staff: { engineer: 1 },
    planet_requirement: :ice_or_ocean,
    tiers: 1..3
  }
}
```

**Processing & Refinement:**
```ruby
REFINERIES = {
  ore_refinery: {
    inputs: { raw_ore: 100, energy: 20 },
    outputs: { refined_metal: 30 },
    staff: { engineer: 2, governor: 1 },
    efficiency_range: 0.5..1.5  # Based on staff skill
  },
  chemical_plant: {
    inputs: { gas: 50, water: 20, energy: 30 },
    outputs: { chemicals: 40 },
    staff: { engineer: 3 },
    hazard_modifier: 1.5  # Higher breakdown chance
  }
}
```

**Infrastructure:**
```ruby
INFRASTRUCTURE = {
  warehouse: {
    storage: 10000,  # tons
    decay_rate: 0.01,  # 1% per day without maintenance
    staff: { governor: 1 },
    defense_bonus: 0
  },
  habitat: {
    population_support: 1000,
    tax_generation: true,
    staff: { governor: 2, marine: 1 },
    morale_factors: [:food_supply, :entertainment, :security]
  },
  defense_platform: {
    firepower: 100,
    range: 10,  # grid units
    staff: { marine: 3 },
    activation: :battle_mode_only
  }
}
```

#### **5.2.2. Building State Machine**

```ruby
class Building < ApplicationRecord
  state_machine initial: :constructing do
    state :constructing do
      # Requires construction materials in system
      # Takes time based on tier
    end

    state :operational do
      # Producing/processing at current efficiency
      # Can receive upgrades
    end

    state :damaged do
      # Reduced efficiency (T1-T3 failures)
      # Can be repaired remotely
    end

    state :offline do
      # Zero production (T4-T5 failures)
      # Requires physical presence or towing
    end

    state :abandoned do
      # No staff assigned
      # Decays over time
    end

    state :destroyed do
      # Permanent, creates salvage
    end

    event :complete_construction do
      transition constructing: :operational
    end

    event :breakdown do
      transition operational: :damaged,
                 damaged: :offline
    end

    event :catastrophic_failure do
      transition any => :offline
    end

    event :abandon do
      transition [:operational, :damaged] => :abandoned
    end

    event :destroy do
      transition any => :destroyed
    end
  end

  def current_efficiency
    base = 1.0
    base *= 0.5 if damaged?
    base *= staff_skill_modifier
    base *= racial_bonus_modifier
    base.clamp(0.1, 2.0)
  end
end
```

#### **5.2.3. Production Cycles**

Buildings operate on hourly ticks:

```ruby
class ProductionJob < ApplicationJob
  def perform
    Building.operational.find_each do |building|
      # Check staff morale/presence
      next if building.on_strike?

      # Check input availability
      inputs_available = building.check_inputs
      next unless inputs_available

      # Calculate output with efficiency
      base_output = building.base_output
      actual_output = base_output * building.current_efficiency

      # Add randomness based on NPC chaos
      chaos_modifier = building.chaos_modifier
      actual_output *= rand(1 - chaos_modifier..1 + chaos_modifier)

      # Deduct inputs, add outputs
      building.consume_inputs!
      building.produce_outputs!(actual_output)

      # Roll for breakdown
      if rand < building.breakdown_chance
        building.breakdown!
      end
    end
  end
end
```

### **5.3. System Ownership Mechanics**

#### **5.3.1. Discovery vs. Dominion**
* **Discovery:** The act of "Scanning" a system for the first time.
  * *Reward:* "First Discovered By" permanent tag. One-time XP/Credit bonus.
  * *Rights:* None. The system is "Neutral Space."
* **Dominion:** The act of establishing political control over the system.
  * *Rights:* Taxation, Security Control, Naming.

#### **5.3.2. The Claim Building: Starbase Administration Hub**
* **Limit:** Max 1 per Star System.
* **Construction:** Expensive. Requires "Construction Drones" and T2 Minerals.
* **Operational Requirement:** Must be staffed by an NPC of the **Governor Class**.
  * *The Bottleneck:* You cannot own more systems than you can afford to pay Governors for. High-tier systems require High-Tier Governors to manage the complexity (Population/Traffic).

#### **5.3.3. Ownership Decay (The Coup)**
* **Trigger:** If the Governor is unpaid, suffers a morale break, or is poached by a rival.
* **State Change:** The Hub goes "Offline."
* **Consequence:**
  * Taxation stops.
  * System reverts to "Neutral."
* **Vulnerability:** Another player can now build their own Hub (or hack yours) to claim the system.

### **5.4. The End-Game: Becoming a Spawn Hub**

#### **5.4.1. The "Franchise" Requirement**
Players cannot simply open a door for new users; they must prove their system is a viable habitat. The System acts as a "Safety Inspector" before allowing a player base to become a Spawn Point.

#### **5.4.2. The Colonial Beacon (Building)**
* **Cost:** Massive. Requires "Super-Alloys" and End-Game Tech.
* **Function:** Initiates the "Certification Audit."

#### **5.4.3. The Certification Audit (System Logic)**
Once the Beacon is built, the Server monitors the system for a 7-day probationary period.

* **Criteria for Success:**
  1. **Economic Liquidity:** Market must contain > [X] Fuel and [Y] Food.
  2. **Opportunity:** System must have > [Z] active "Buy Orders" or "Employment Slots" (ensuring new players have tasks).
  3. **Safety:** No "Catastrophic" events or successful PvP raids for 7 days.
* **Failure:** If metrics drop below the threshold, the Audit resets.

#### **5.4.4. The Reward: Tax & Labor**
* **Immigration:** Successful hubs are listed in the "Phase 3 Selection Screen."
* **The Kickback:** The Owner receives a 5% Tax on *all* credits generated by players who spawn there for their first 30 days.
* **Strategic Impact:** This creates competition among end-game players to build attractive, safe hubs to lure "Human Resources" (Newbies) to their region to fuel their economy.

## **6. Information Economy**

### **6.1. Market Fog of War**
* **Rule:** Market data (Prices, Inventory) is **NOT** globally available.
* **Visibility:** A player can only view market data for systems they have **personally visited** (docked at).
* **Staleness Mechanics:**
  * **Visited (History):** Shows the "Last Known Price" (Snapshot at time of visit).
  * **Active Presence:** If a player has a ship or building currently in the system, they see "Live Data."
* **Gameplay Loop:** This forces players to actively explore nearby systems to find arbitrage opportunities. You cannot simply query the database for "Cheapest Iron"; you must go look for it.

### **6.2. Success Criteria**

**Done when:**
- [ ] Market data only visible for visited systems
- [ ] Unvisited systems show no price data
- [ ] Last known prices shown with timestamp for visited systems
- [ ] Live data only for systems with active player presence
- [ ] No global price search available

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| Data visibility | Visit required | `unvisited_system.market_data == nil` |
| Price staleness | Timestamp shown | `visited_system.price_timestamp != nil` |
| Live updates | Presence required | `live_prices if player.assets_in_system?` |

**Fails if:**
- Players can see prices without visiting
- Global price search exists
- Market data updates without player presence

## **7. User Interface (UI)**
* Style: Text-based, CLI-inspired. **Rendered as HTML, not ASCII art.**
* Feedback: "Just commands and information." No 3D rendering.
* Input: Players type commands or select options (e.g., `> warp to sector 4`, `> scan local`, `> buy 500 iron`).
* Visuals: Information is conveyed via text descriptions and data tables. Sparse, clean, terminal aesthetic — but proper HTML elements (divs, tables, buttons), not ASCII box-drawing characters.
* Tech: Rails 8 + Turbo + Stimulus. Tailwind CSS. Monospace font for the terminal feel.
* **Color Palette:**
  * Background: Dark blue
  * Primary accent: Orange
  * Secondary: Lime green
  * Tertiary: `#79bffd` (light blue)
  * Text: White

## **8. Technical Considerations**
* Database: Light schema. Only stores "Deltas" and Player Asset States.
* Asset Table: Needs flexible schema to handle procedurally generated attributes for thousands of unique ship/building types.

### **8.1. Success Criteria**

**Done when:**
- [ ] Database stores only player actions and deltas
- [ ] System properties never stored (always generated)
- [ ] Assets table uses JSONB for procedural attributes
- [ ] Schema supports 10,000+ unique asset types without migration

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| DB size | <1GB for 10k players | Monitor after load test |
| Asset flexibility | Any attribute combo | `Asset.create!(attributes: {any: "data"})` |
| Query performance | <5ms for lookups | `EXPLAIN ANALYZE` on key queries |

**Fails if:**
- Procedural data stored in database
- Schema changes needed for new asset types
- Queries slow down with scale

## **9. Racial Archetypes (The Builders)**
Assets are not generic; they are manufactured by specific civilizations. The "Manufacturer" attribute dictates the stat distribution and special abilities of Ships and Buildings.

### **9.1. The Vex (The Aggressive Traders)**
* *Archetype:* Ferengi / Hutt.
* *Focus:* Profit, Cargo Volume, Smuggling.
* *Ship Traits:* **"The Hauler."** Massive cargo holds, hidden compartments (smuggling bonus), weak shields, reliance on speed or bribery.
* *Building Traits:* Casinos, Trade Hubs, Black Markets. High income generation but high corruption/crime rates.

### **9.2. The Solari (The Logic Scientists)**
* *Archetype:* Vulcan / Asgard.
* *Focus:* Exploration, Sensors, Shields.
* *Ship Traits:* **"The Explorer."** Best-in-class Warp Drives, deep-space scanners, high shield regeneration, low hull armor. Expensive to repair.
* *Building Traits:* Research Labs, Sensor Arrays, Shield Generators. High energy consumption but provides the best Intel/Data.

### **9.3. The Krog (The Industrial Warriors)**
* *Archetype:* Klingon / Krogan.
* *Focus:* Durability, Mining, Boarding Actions.
* *Ship Traits:* **"The Brick."** Heavy armor plating, bonus Marine slots (for boarding), slow engines, high fuel consumption.
* *Building Traits:* Refineries, Shipyards, Bunkers. Extremely durable (hard to sabotage) but produce high pollution (lowers planet happiness).

### **9.4. The Myrmidon (The Hive Mind)**
* *Archetype:* Borg / Zerg / Insectoid.
* *Focus:* Mass Production, Cheap, Modular.
* *Ship Traits:* **"The Swarm."** Very cheap to buy, modular slots (can be refitted easily), low individual durability, "Organic Hull" (slow self-repair).
* *Building Traits:* Hydroponics, Clone Vats, Housing. Very efficient at supporting high populations/workforce.

### **9.5. The Pips (The Unlisted Race)**
* **Archetype:** Tribbles / Gremlins / Minions.
* **Description:** Never visually described. Text references always evade specifics (e.g., *"The small, furry nightmare,"* *"The cute menace,"* *"Those things"*).
* **Behavior:** They are not built; they are an infestation. They randomly appear on ships/buildings that have low maintenance or visit "High Risk" bio-sectors.

### **9.6. Success Criteria**

**Done when:**
- [ ] Each race has distinct statistical advantages
- [ ] Vex ships: +20% cargo capacity vs global average
- [ ] Solari ships: +20% sensor range vs global average
- [ ] Krog ships: +20% hull points vs global average
- [ ] Myrmidon ships: -20% cost vs global average
- [ ] Racial buildings have unique resource requirements
- [ ] Pips appear only as infestations, never built

**Measured by:**
| Race | Ship Bonus | Building Focus |
|------|------------|----------------|
| Vex | Cargo +20% | High income, high corruption |
| Solari | Sensors +20% | High tech, high energy use |
| Krog | Hull +20% | High durability, high pollution |
| Myrmidon | Cost -20% | Efficient population support |

**Fails if:**
- Racial bonuses not statistically significant
- All races play the same
- Pips can be built/purchased

## **10. Asset & NPC Generation Targets**
The procedural engine must meet the following quantitative targets to ensure a diverse ecosystem.

### **10.1. Ship Generation Targets**
* **Total Unique Hulls:** ~200.
* **Formula:** `4 Races` x `5 Hull Sizes` (Scout, Frigate, Transport, Cruiser, Titan) x `10 Variants` = **200 Ships.**
* **Attribute Integrity Check:**
  * *Vex* ships must have 20% higher Cargo Capacity than the global average.
  * *Solari* ships must have 20% higher Sensor Range than the global average.
  * *Krog* ships must have 20% higher Hull Points than the global average.

### **10.2. Building Generation Targets**
* **Total Unique Structures:** ~100.
* **Formula:** `4 Races` x `5 Functions` (Extraction, Refining, Logistics, Civic, Defense) x `5 Tiers` = **100 Buildings.**
* **Attribute Integrity Check:**
  * Building Tiers must follow the Power Law (Cost increases by 1.8x, Output increases by 2.5x).
  * Racial buildings must require unique input materials (e.g., Solari buildings require more "Crystals/Electronics," Krog buildings require more "Steel/Concrete").

### **10.3. NPC Generation Targets**
* **Total Unique Variations:** Infinite (Procedural).
* **Racial Bonuses:**
  * *Vex NPC:* +10 Barter Skill / +5 Luck / Trait: "Greedy" (Higher Salary).
  * *Solari NPC:* +10 Science Skill / +5 Navigation / Trait: "Cold" (Low Morale impact).
  * *Krog NPC:* +10 Combat Skill / +5 Engineering / Trait: "Volatile" (High Strike chance).
  * *Myrmidon NPC:* +10 Agriculture / +5 Industry / Trait: "Hive Mind" (Must be hired in groups of 3+).

### **10.4. Success Criteria**

**Done when:**
- [ ] 200 unique ship hulls generated (4 races × 5 sizes × 10 variants)
- [ ] 100 unique buildings generated (4 races × 5 functions × 5 tiers)
- [ ] Racial integrity maintained in generation
- [ ] Building tiers follow power law scaling
- [ ] NPC racial bonuses apply correctly

**Measured by:**
```ruby
# Ship diversity test
ships = generate_all_ship_variants
assert ships.uniq.count == 200
assert ships.group_by(&:race).all? { |race, ships| verify_racial_bonus(race, ships) }

# Building tier scaling
tiers = Building::TIERS
tiers.each_cons(2) do |t1, t2|
  assert t2.cost == t1.cost * 1.8
  assert t2.output == t1.output * 2.5
end
```

**Fails if:**
- Duplicate ship variants generated
- Racial bonuses not applied
- Tier scaling incorrect
- Missing any race/size/variant combination

## **11. Messaging & Notifications (The Inbox)**
The Inbox is the primary feedback loop for the "Tycoon" layer. It is not just a chat log; it is an actionable dashboard.

### **11.1. Success Criteria: Functional**
* **Actionable Alerts:** Critical messages must include an inline command (e.g., "Engine Failure on Ship A" -> `[Cmd: Repair ($500)]`).
* **Filtering:** Players must be able to filter by "Urgent," "Trade," "Personnel," and "Discovery."
* **Capacity:** The inbox must handle high throughput (e.g., 50 automated ships reporting in simultaneously) by grouping similar messages (e.g., "7 Ships arrived at Hub A").

### **11.2. Success Criteria: Narrative (Racial Voice)**
NPCs must communicate in the "Voice" of their race to increase immersion.
* **Vex (Trader):** Transactional and emotional regarding money.
  * *Success:* "Boss! We fleeced them! Sold 500 Iron at 200% markup!"
  * *Failure:* "I'm not paid enough for this. Hull integrity at 40%. Send cash or I walk."
* **Solari (Scientist):** Precise, probability-based, cold.
  * *Success:* "Route calculation complete. Efficiency increased by 4.2%."
  * *Failure:* "Critical failure in drive core. Probability of explosion: 98%. Evacuating."
* **Krog (Warrior):** Blunt, aggressive, honor-based.
  * *Success:* "We crushed the pirates! Their scrap is ours."
  * *Failure:* "The ship is bleeding! We need armor, not excuses!"
* **Myrmidon (Hive):** Collective, cryptic, hunger-focused.
  * *Success:* "The Hive grows. Resources acquired."
  * *Failure:* "Drone #482 has expired. Replacement required."

### **11.3. Content Strategy: The "Petty Universe"**
While the economy is serious, the characters inhabiting it are flawed, petty, and bureaucratic. The Inbox serves as the comic relief by juxtaposing high-stakes sci-fi concepts with mundane, workplace complaints.

#### **11.3.1. The "Mad Libs" Complaint System**
System messages should use a slot-filling grammar to generate unique, often absurd scenarios.
* **Structure:** `[NPC_Name]` is `[Negative_State]` because `[Mundane_Object]` is `[SciFi_Problem]`.
* **Example Output:** *"Chief Engineer Grak is **furious** because the **coffee machine** is **emitting gamma radiation**."*
* **Example Output:** *"Navigator Xyl is **depressed** because the **star charts** represent **an existential void**."*

#### **11.3.2. Racial Humor Dynamics**
* **Vex (Greed):** Humor comes from absurd cost-cutting.
  * *Inbox:* "Captain, I replaced the escape pods with vending machines to maximize revenue per square foot. You're welcome."
* **Solari (Logic):** Humor comes from taking things too literally.
  * *Inbox:* "I have analyzed the concept of 'Fun'. It is inefficient. I have removed the crew lounge to increase productivity by 0.04%."
* **Krog (Violence):** Humor comes from over-reacting to small problems.
  * *Inbox:* "The toilet was clogged. I destroyed it with a plasma grenade. Glory to the Empire!"
* **Myrmidon (Hive):** Humor comes from a lack of individuality.
  * *Inbox:* "Unit #442 suggests we consume the passengers. They look high in protein. Awaiting consensus."

### **11.4. Success Criteria**

**Done when:**
- [ ] Inbox displays messages in reverse chronological order
- [ ] Critical messages have inline actionable commands
- [ ] Messages can be filtered by category (Urgent, Trade, Personnel, Discovery)
- [ ] Similar messages are grouped (e.g., "7 Ships arrived at Hub A")
- [ ] Each race uses distinct voice/personality in messages
- [ ] Mad Libs system generates unique complaint variations
- [ ] Message throughput handles 50+ simultaneous reports

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| Message display | <50ms | Load time for 100 messages |
| Grouping threshold | 5+ similar | `"7 ships arrived"` not 7 separate messages |
| Voice consistency | 100% | All Vex messages mention money/profit |
| Mad Libs variety | 1000+ combos | Unique message generator test |

**Fails if:**
- Messages take >100ms to load
- Racial personalities blend together
- Same exact message appears repeatedly
- Actionable messages lack inline commands
- High-volume notifications crash the UI

## **12. Data Persistence & Schema Strategy**
To manage the "Infinite" world while tracking granular player history, we employ a "Just-in-Time" realization strategy.

### **12.1. System Discovery Logic**
* **The "Realization" Event:** When a player scans a valid coordinate hash, the server "Realizes" the system.
* **Success Criteria:**
  * Create a row in the `systems` table with the fixed Seed ID.
  * Assign `discovered_by_player_id` (The "First Flag").
  * Generate the initial snapshot of the market/resources.
* **Notification:** Broadcast a "Galaxy First" event if it is a major find.

### **12.2. The "Guest Book" (Visitor Logging)**
Every system maintains a log of who has docked there.
* **Schema:** `system_visits` table.
* **Fields:** `system_id`, `player_id`, `timestamp`, `action` (e.g., "Docked", "Scanned", "Attacked").
* **Constraint:** To prevent database bloat, this table uses a "Hot/Cold" strategy. Recent visits (last 30 days) are fast-access; older visits are archived to cold storage logs.

### **12.3. The "Flight Recorder" (Player Movement History)**
Players have a permanent log of their journey ("The Breadcrumb Trail").
* **Visual Output:** Players can view a "Travel Map" showing their lifetime path through the stars.
* **Schema:** `flight_logs` table (TimeSeries).
* **Fields:** `player_id`, `origin_coords`, `dest_coords`, `fuel_consumed`, `timestamp`.
* **Success Criteria:**
  * Must support querying "Where was I 3 months ago?"
  * Must support "Heatmap" generation (showing most traveled routes).

### **12.4. Schema Architecture Success Criteria**
* **Asset Flexibility:** The `assets` table must use a JSONB (or EAV) column for `attributes` to allow for the infinite variations of procedurally generated ships/buildings without altering the table structure.
* **NPC State:** The `npcs` table must track `morale`, `age`, and `employer_history` to support the "Poaching" mechanic.

### **12.5. Entity Naming Convention (Triple-ID System)**

Every entity in the system has three identifiers:

| Layer | Purpose | Example |
|-------|---------|---------|
| **Full Name** | Human-readable display name | "Yamato" |
| **Short ID** | User-typeable abbreviation | `sh-yam` |
| **Internal ID** | Database primary key (UUID v7) | `01956e8a-3b2c-7d4e-...` |

**Why Three IDs:**
- Users see and remember the Full Name
- Users type the Short ID in commands (faster than full names)
- System uses UUID v7 internally (time-sortable, globally unique)
- Users never need to know or type the UUID

**Short ID Format:** `{prefix}-{identifier}`

**Prefixes by Entity Type:**
| Entity | Prefix | Short ID Example | Full Name Example |
|--------|--------|------------------|-------------------|
| Ship | `sh-` | `sh-yam` | Yamato |
| Route | `rt-` | `rt-vcs` | Vigby → Chug → Szaps |
| Building | `bl-` | `bl-ref7` | Refinery-7 |
| Worker | `wk-` | `wk-gra` | Eng. Grak |
| System | `sy-` | `sy-vig` | Vigby |
| Planet | `pl-` | `pl-vig2` | Vigby II |

**Identifier Rules:**
- **Ships:** First 3 letters of ship name (`Yamato` → `yam`)
- **Routes:** First letter of each stop (`Vigby→Chug→Szaps` → `vcs`)
- **Buildings:** Abbreviated type + number (`Refinery-7` → `ref7`)
- **Workers:** First 3 letters of surname/name (`Grak` → `gra`)
- **Systems:** First 3 letters of system name (`Vigby` → `vig`)
- **Planets:** System short + planet number (`Vigby II` → `vig2`)

**Collision Handling:**
When a short ID already exists, append incrementing number:
- First "Yamato" → `sh-yam`
- Second "Yamato" → `sh-yam2`
- Third "Yamato" → `sh-yam3`

**Schema:**
```ruby
class Ship < ApplicationRecord
  # id: uuid (v7, primary key)
  # name: string (Full Name)
  # short_id: string (unique, indexed)
  
  before_create :generate_short_id
  
  private
  
  def generate_short_id
    base = "sh-#{name[0, 3].downcase}"
    candidate = base
    counter = 2
    while Ship.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end
    self.short_id = candidate
  end
end
```

**Command Usage:**
```
> warp sh-yam to sy-vig     # Warp ship Yamato to Vigby
> assign wk-gra to sh-ent   # Assign worker Grak to Enterprise
> route create rt-vcs       # Create route through Vigby, Chug, Szaps
```

## **13. Travel Mechanics & Infrastructure**

### **13.1. Movement & Time**
* **The "Tick" Cost:** Movement is not instantaneous. It costs **Time** and **Fuel**.
* **Base Speed:** 60 Seconds per Coordinate Grid (Standard Engine).
* **Upgrade Cap:** High-tier engines/skills can reduce this to ~10 Seconds per Grid.
* **UI Feedback:** Players see a countdown timer during travel: `Status: En Route to [System X]... Arriving in 43s.`

### **13.2. The Warp Gate Network (The Highway)**
* **Function:** A constructible building that allows rapid travel to a "Nearest Neighbor" gate.
* **Cost:**
  * *Fuel Fee:* Charged to the traveler. Lower than the cost of manual flight.
  * *Distribution:* X% burned for travel, Y% goes to the Gate Owner's "Maintenance Fund," Z% is profit for the owner.
* **Time Cost:** Warping takes the same time as traveling **1 Coordinate** manually.
  * *Strategy:* A 10-gate chain covers massive distance but still takes `10 * Ship_Speed` seconds to traverse. This keeps the universe feeling large.
* **Limitation:** Gates must be "linked." You cannot warp to a gate 10,000 units away; you must warp to the *next* gate in the chain.

### **13.3. Navigation UI**
* **The "Short List":** The travel command `> warp` or `> move` displays a dynamic list:
  1. **Bookmarks:** (Player defined, e.g., "Home Base", "Good Mine").
  2. **Recent History:** Last 5 systems visited (Auto-generated).
  3. **Local Neighbors:** Systems reachable with current fuel.

### **13.4. System Entry Intentions**
Upon entering a system, players must declare their **intention**:

* **Trade Mode:** Access to markets, refineries, and docking. Peaceful interactions only.
* **Battle Mode:** Hostile entry. The system's **defense grid** engages immediately.

**Rules:**
* **Locked While Present:** You cannot switch intentions while in the system.
* **Leave to Switch:** Departure and re-entry required to change modes.
* **Strategic Implication:** Raiding a system means forfeiting trade access until you leave. Defending systems invest in defense infrastructure to punish raiders.

**UI Flow:**
```
> warp sy-rig
Destination: Rigel Prime (sy-rig)
Distance: 4.2 LY | ETA: 3 hours

[T] Trade - Enter peacefully
[B] Battle - Engage defenses

Select intention: _
```

**Success Criteria:**
- [ ] System entry requires intention selection (Trade/Battle)
- [ ] Intention locked while in system (cannot switch)
- [ ] Battle mode triggers defense grid combat
- [ ] Test: Enter trade → try switch → rejected; leave → re-enter battle → works

### **13.5. Success Criteria**

**Done when:**
- [ ] Movement takes time based on distance (60s per grid baseline)
- [ ] Fuel consumption scales with distance
- [ ] Warp gates allow rapid travel between connected gates only
- [ ] Navigation shows bookmarks, recent history, and reachable systems
- [ ] System entry requires Trade/Battle mode selection
- [ ] Mode locked while in system (must leave to change)
- [ ] Warp gate fees distributed: X% burned, Y% maintenance, Z% profit

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| Base travel speed | 60s/grid | `assert travel_time(1) == 60` |
| Max travel speed | 10s/grid | With best engine + navigator |
| Gate travel time | Same as 1 grid | Regardless of gate distance |
| Navigation list | <5ms render | For 20 destinations |
| Mode switching | Blocked in system | `in_system? && !can_switch_mode?` |

**Fails if:**
- Travel is instantaneous (no time cost)
- Gates allow arbitrary distance jumps
- Can switch modes without leaving system
- Navigation shows unreachable destinations
- Fuel not consumed during travel

## **14. Starter Quests (Onboarding)**
New players spawn in one of the 6 Core Galaxies. Each Galaxy has a "Flavor" and a specific NPC guide who introduces mechanics via "Petty Problems."

### **14.1. Galaxy A: "The Rusty Belt" (Krog Controlled)**
* **Theme:** Industrial, heavy metal, dangerous.
* **NPC Guide:** **Foreman Zorg (Krog)**. Traits: Aggressive, Loud, Impatient.
* **Quest 1: "The Coffee Run"**
  * *Context:* "The cafeteria droid broke. The workers are rioting. I need Caffeine Sludge NOW."
  * *Task:* Travel to neighboring system `Sector-9`, buy 10 tons of `Bio-Waste`, refine it into `Caffeine`.
  * *Lesson:* Movement, Trading, Refining.
* **Quest 2: "Smash the Competitor"**
  * *Context:* "A drone is scanning *my* asteroid. Go scare it off."
  * *Task:* Engage a weak NPC drone in combat.
  * *Lesson:* Combat commands, Looting.

### **14.2. Galaxy B: "The Neon Spire" (Vex Controlled)**
* **Theme:** Corporate, high-tech, corrupt.
* **NPC Guide:** **Broker Sly (Vex)**. Traits: Whispering, Nervous, Greed.
* **Quest 1: "Tax Evasion"**
  * *Context:* "The auditors are coming. I need to hide this 'undeclared cargo' off-planet."
  * *Task:* Move 5 tons of `Luxury Goods` to a hidden moon before the timer expires (10 minutes).
  * *Lesson:* Speed Navigation, Cargo Management.
* **Quest 2: "The Insider Tip"**
  * *Context:* "I heard minerals are cheap in `Sector-4`. Go buy them all before the market realizes."
  * *Task:* Buy Low in A, Sell High in B.
  * *Lesson:* Market Arbitrage, Price Deltas.

### **14.3. Galaxy C: "The Void Lab" (Solari Controlled)**
* **Theme:** Sterile, scientific, cold.
* **NPC Guide:** **Lead Researcher 7-Alpha (Solari)**. Traits: Literal, Emotionless.
* **Quest 1: "Data Collection"**
  * *Context:* "We require data on the mating habits of space whales. Do not ask why."
  * *Task:* Equip a `Scanner`, travel to `Deep Space Node X`, perform a scan.
  * *Lesson:* Scanning, Modules, Exploration.
* **Quest 2: "The Gate Test"**
  * *Context:* "We have constructed a prototype gate. Test it. Probability of atomization is only 4%."
  * *Task:* Use a Warp Gate to travel to a distant node.
  * *Lesson:* Warp Mechanics, Gate Fees.

### **14.4. Galaxy D: "The Hive" (Myrmidon Controlled)**
* **Theme:** Organic, creepy, biological.
* **NPC Guide:** **Cluster 8 (Myrmidon)**. Traits: Plural pronouns ("We"), Hungry.
* **Quest 1: "Feeding Time"**
  * *Context:* "The Larvae are hungry. The nutrient paste is depleted."
  * *Task:* Mine `Ice` from a nearby belt and convert it to `Water`.
  * *Lesson:* Mining, Resource Conversion.
* **Quest 2: "Expand the Colony"**
  * *Context:* "We require more space. Deliver these construction drones."
  * *Task:* Transport `Drone Parts` to a construction site.
  * *Lesson:* Building/Infrastructure.

### **14.5. Success Criteria**

**Done when:**
- [ ] Each galaxy has unique theme and NPC guide
- [ ] Quest 1 teaches basic mechanics (movement, trading)
- [ ] Quest 2 introduces advanced mechanics per galaxy
- [ ] All quests completable by new players
- [ ] Quest rewards sufficient to progress
- [ ] NPC dialogue matches racial personality

**Measured by:**
| Galaxy | Theme | Quest 1 Mechanic | Quest 2 Mechanic |
|--------|-------|------------------|------------------|
| Rusty Belt | Industrial | Trading + Refining | Combat |
| Neon Spire | Corporate | Timed delivery | Arbitrage |
| Void Lab | Scientific | Scanning | Warp gates |
| The Hive | Biological | Mining | Construction |

**Fails if:**
- Quest impossible for new player to complete
- Rewards insufficient to continue
- NPC personality doesn't match race
- Tutorial doesn't teach stated mechanics

## **15. The "Catastrophe" Mechanic (Anti-Automation)**
While standard breakdowns can be fixed by spending credits remotely, **Catastrophic Events** require the player to physically travel to the asset to resolve them.

### **15.1. The 1% Rule (The Pip Factor)**
* **Trigger:** Every time an asset rolls for a standard failure (e.g., "Engine Breakdown"), there is a **1% Override Chance** that the cause is **Pips**.
* **The Effect:** The asset is **Disabled (Offline)**. It generates $0 income and cannot move until the player docks with it and executes the "Purge" command.

### **15.2. Procedural Catastrophe Generation (The Humor)**
Pip events must be elaborate, specific, and ridiculous.
* **Formula:** `[Critical_System]` disabled because Pips `[Absurd_Action]` resulting in `[Ridiculous_Consequence]`.
* **Example A (Weapon Failure):** *"Laser Battery 1 is offline. The Pips **built a nest inside the focusing lens** using your **socks**. The beam refracted and **melted the coffee maker**."*
* **Example B (Cargo Loss):** *"Cargo Bay 4 is empty. A Pip **hit the emergency jettison button** because it **liked the flashing red light**. 50 tons of Gold are now orbiting a gas giant."*
* **Example C (Navigation Error):** *"The Autopilot is locked. The Pips **re-wired the nav computer** to fly toward the nearest **Supernova** because they thought it looked **warm**."*

### **15.3. The "Hands-On" Requirement**
* **Why:** This prevents "AFK Empires." A player with 500 automated ships will eventually have 5 of them disabled by Pips. If they don't log in and fly out to "de-louse" their fleet, their empire slowly crumbles.
* **The Fix:**
  1. Player receives Inbox Alert: *"URGENT: Pip Infestation on Hauler Alpha-9."*
  2. Player must **fly their character** to the system where Hauler Alpha-9 is stranded.
  3. Player enters command: `> board ship` -> `> purge pips`.
  4. Reward: A small amount of "Pip Fur" (Tradeable luxury item? Fuel source?) and the ship returns to service.

### **15.4. The Chaos Scale (Severity Tiers)**
When an asset fails (due to low maintenance or NPC error), the **Severity** of the failure is determined by the assigned NPC's hidden **Chaos Factor**.

* **T1: Minor Glitch (The Coffee Maker)**
  * **Loss:** 5% Functionality (Asset runs at 95% efficiency).
  * **Cost:** Negligible (or 1 Pip Fur).
  * **Flavor:** *"Sensors misalignment,"* *"Vending machine fire,"* *"Employee drama."*
  * **Fix:** Auto-resolves over time or instant fix for small cash.
* **T2: Component Failure**
  * **Loss:** 15% Functionality (Speed/Output reduced).
  * **Cost:** Low (Requires spare parts).
  * **Flavor:** *"Power coupling fused,"* *"Cargo loader jammed."*
  * **Fix:** Requires `Spare Parts` in cargo hold.
* **T3: System Failure**
  * **Loss:** 35% Functionality (Asset cannot Warp or Refine).
  * **Cost:** Medium (Requires expensive components).
  * **Flavor:** *"Reactor coolant leak,"* *"Nav-computer wipe."*
  * **Fix:** Requires `Advanced Components` + 1 Hour Repair Time.
* **T4: Critical Damage**
  * **Loss:** 50% Functionality (Asset is dead in the water/offline).
  * **Cost:** High (Requires T3 components + Specialist intervention).
  * **Flavor:** *"Hull breach,"* *"Drive core fracture."*
  * **Fix:** Requires **Co-op Repair** or **Towing** to a drydock.
* **T5: Catastrophe (The Explosion)**
  * **Loss:** 80% Functionality (Asset is effectively a wreck).
  * **Cost:** Massive (Almost the price of a new hull).
  * **Flavor:** *"Engine explosion,"* *"AI Mutiny,"* *"Pip Infestation (Total)."*
  * **Fix:** Requires physical presence of Player + "Rebuild Kit."

### **15.5. The Personnel Record (The Detective Game)**
Since the **Chaos Factor (0-100)** is hidden, players must evaluate NPCs based on their **Service Record**.

* **The Log:** Every time an NPC is assigned to an asset that suffers a breakdown, a permanent entry is added to their record.
* **The Ambiguity:**
  * *Was it the NPC?* Or was the ship just old?
  * *The Clue:* If a ship breaks down 5 times, it might be the ship. If an NPC moves to a *new* ship and *that* ship immediately has a T5 explosion, the NPC is the common denominator.
* **UI - The "Rap Sheet":**
  * *Name:* Eng. Zorg (Krog)
  * *Skill:* 85 (Excellent)
  * *Salary:* 500/week
  * *Incidents:*
    * `[Date]`: T1 Glitch (Coffee Machine)
    * `[Date]`: T1 Glitch (Air Conditioning)
    * `[Date]`: **T5 Catastrophe (Reactor Meltdown)**
* **Strategy:** The player must decide: *"Is Zorg's Level 85 skill worth the risk that he might blow up my ship again?"*

### **15.6. Success Criteria**

**Done when:**
- [ ] 1% of standard failures escalate to Pip catastrophes
- [ ] Catastrophic failures require physical player presence to fix
- [ ] Pip events generate unique, humorous descriptions
- [ ] NPC Chaos Factor (0-100) hidden but affects failure severity
- [ ] Service records show all incidents with timestamps
- [ ] Severity tiers (T1-T5) have distinct costs and consequences
- [ ] High-chaos NPCs have more incidents in their history

**Measured by:**
| Metric | Target | Verify |
|--------|--------|--------|
| Pip trigger rate | 1% of failures | Over 10k failure events |
| Message variety | 100+ unique | No duplicate Pip descriptions |
| Chaos correlation | r > 0.7 | Chaos Factor vs incident rate |
| T5 recovery cost | 80% of new asset | Nearly cheaper to replace |
| Remote fix | Impossible for Pips | Requires physical presence |

**Fails if:**
- All failures can be fixed remotely (no travel incentive)
- Pip events use generic descriptions
- Chaos Factor visible to players
- Service records don't persist across employers
- AFK players can maintain large fleets indefinitely

## **16. User Interface (Technical Guidance)**
The CLI interface uses a hierarchical menu system with VI-style navigation.

### **16.1. Core Principles**
* **Speed:** The screen must update **instantly**. No perceptible lag.
* **Keyboard First:** All actions must have keyboard shortcuts.
* **VI Navigation:** `j`/`k` to move up/down, `Enter` to select, `Esc` or `q` to go back.

### **16.2. Menu Structure**
The main menu is a vertical list anchored to the left side of the screen. The player's name appears at the top.

```
PlayerName
  Inbox
  Chat
  Navigation
  Systems
    └─ Buildings
  Ships
    ├─ Trading
    └─ Combat
  Workers
  About
```

### **16.3. Layout Behavior**
* **Desktop:** Menu on the left, content panel on the right.
* **Selection:** Clicking/selecting a menu item highlights it and updates the content panel.
* **Submenus:** Selecting an item with children (e.g., Ships) displays the submenu inline.

### **16.4. Breadcrumb Navigation**
When drilling into nested views, the menu collapses and breadcrumbs appear at the top.

**Example Flow:**

**State 1: Home (Inbox selected)**
```
PlayerName
  Inbox ───────┤ System Status messages
  Chat         │ ────────────────────────────────────
  Navigation   │ Route rt-vcs - down in profits $3: Gold more expensive than usual
  Systems      │ Ship sh-4em - destroyed by meteor, all lives lost
  Ships        │ New Hire Sam - arrived at Vigby, will board sh-n3z when it arrives
  Workers      │
  About        │
```

**State 2: User clicks "Ships" → Submenu appears**
```
PlayerName
  Inbox ───────┤ Trading  │ List of ships
  Chat         │ Combat   │   - Yamato
  Navigation   │          │   - Enterprise
  Systems      │          │   - Nostromo
  Ships ◄──────┤          │
  Workers      │          │
  About        │          │
```

**State 3: User clicks "Trading" → Menu collapses, breadcrumbs appear**
```
PlayerName > Ships
  Trading ◄────┤ Trading
  Combat       │ ─────────────────────────────────────
               │ Routes
               │   - rt-vcs: Vigby -> Chug -> Szaps -> Vigby ($34/hr)
               │   - rt-abm: Affle -> Bont -> Murke -> Affle ($89/hr)
```

**State 4: User clicks a Route → Deeper drill-down**
```
PlayerName > Ships > Trading
  Routes ◄─────┤ Vigby -> Chug -> Szaps -> Vigby
               │ ─────────────────────────────────────
               │ Vigby - sell Gold, buy Steel
               │ Chug  - sell Steel, buy Bots
               │ Szaps - sell Bots, buy Gold
```

### **16.5. Navigation Rules**
* **Breadcrumb Click:** Clicking any breadcrumb item returns to that screen.
* **Back:** `Esc` or `q` navigates up one level.
* **Home:** A dedicated shortcut (e.g., `H`) returns to the root menu.

### **16.6. Screen Definitions**

**Rendering Note:** All wireframes below use ASCII for documentation only. The actual UI is **HTML** — sparse, clean, terminal aesthetic with proper elements (divs, tables, buttons). Not ASCII box-drawing in the browser.

**Tech Stack:**
- **Framework:** Rails 8 with Turbo + Stimulus
- **Rendering:** Server-rendered HTML, Turbo Frames for panel updates
- **Style:** Tailwind CSS, monospace font, terminal aesthetic
- **Layout:** Fixed left sidebar (menu), scrollable right panel (content)

**Global Keyboard Shortcuts (always active):**
| Key | Action |
|-----|--------|
| `j` | Move selection down |
| `k` | Move selection up |
| `Enter` | Select / drill into |
| `Esc` | Go back one level |
| `q` | Go back one level (alias) |
| `H` | Go to Home (Inbox) |
| `?` | Show keyboard shortcuts overlay |

---

#### **Screen 1: Inbox (Home Screen)**

**Route:** `/inbox` (root redirects here)

**Purpose:** Activity feed showing all notifications, alerts, and messages from NPCs and systems.

**Data Displayed:**
| Field | Description |
|-------|-------------|
| Icon | `●` unread, `○` read |
| Title | Subject line (NPC name, ship ID, or system event) |
| Body | 1-2 line description |
| Timestamp | Relative time ("2 minutes ago") |
| Tag | Optional urgency tag: `[URGENT]`, `[ACTION REQUIRED]` |

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | Drill into message detail |
| `r` | Toggle read/unread |
| `e` | Delete/archive message |
| `u` | Filter: show unread only |
| `a` | Filter: show all |

**Success Criteria:**
- [ ] Shows all notifications in reverse chronological order
- [ ] Unread count displayed in header
- [ ] `r` toggles read status without page reload
- [ ] `e` archives with undo option

---

#### **Screen 2: Message Detail**

**Route:** `/inbox/:id`

**Purpose:** Full view of a single notification with context and actions.

**Keyboard:**
| Key | Action |
|-----|--------|
| `s` | Send salvage ship (if applicable) |
| `d` | Dismiss message |
| `v` | View related entity (ship, building, system) |
| `Esc` | Back to Inbox |

**Success Criteria:**
- [ ] Shows full message with sender, timestamp, body
- [ ] Context-appropriate action buttons render
- [ ] Links to related entities work

---

#### **Screen 3: Chat**

**Route:** `/chat`

**Purpose:** Player-to-player messaging and guild chat.

**Data Displayed:**
- Channel selector (tabs or dropdown)
- Message history (scrollable)
- Input field at bottom

**Keyboard:**
| Key | Action |
|-----|--------|
| `Tab` | Switch channels |
| `/` | Focus input field |
| `Enter` | Send message (when input focused) |
| `PageUp/Down` | Scroll history |

**Success Criteria:**
- [ ] Messages appear in real-time (ActionCable)
- [ ] Channel switching preserves scroll position
- [ ] Input field clears after send

---

#### **Screen 4: Navigation**

**Route:** `/navigation`

**Purpose:** Map view and travel controls. Shows current location, nearby systems, and active routes.

**Data Displayed:**
| Section | Fields |
|---------|--------|
| Current Location | System name, coordinates, star type, hazard level, ownership |
| Nearby Systems | Name, coordinates, fuel cost, visited status |
| Active Routes | Route ID, stops, assigned ship, ETA, profit/hr |

**Keyboard:**
| Key | Action |
|-----|--------|
| `w` | Warp to selected system |
| `s` | Scan selected system |
| `r` | Go to Routes screen |
| `Enter` | Select system → System Detail |

**Success Criteria:**
- [ ] Only shows systems within current fuel range
- [ ] Visited/unvisited status clearly marked
- [ ] Active routes show real-time ETA

---

#### **Screen 5: Systems**

**Route:** `/systems`

**Purpose:** List of all known (visited) systems with key stats.

**Data Displayed:**
| Column | Description |
|--------|-------------|
| Name | System name |
| Coords | (x, y, z) |
| Star | Star type |
| Hazard | 0-100 danger level |
| Flags | [H] home, [C] controlled, [!] has alerts |

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View System Detail |
| `b` | View Buildings in system |
| `m` | View Market in system |
| `/` | Search/filter systems |

**Success Criteria:**
- [ ] All visited systems listed
- [ ] Sorting by any column works
- [ ] Search filters as you type

---

#### **Screen 6: System Detail**

**Route:** `/systems/:id`

**Purpose:** Full detail view of a single system.

**Keyboard:**
| Key | Action |
|-----|--------|
| `m` | View Market |
| `b` | View Buildings |
| `p` | View Planets (minerals/plants) |
| `w` | Warp here |

**Success Criteria:**
- [ ] Shows all planets with mineral/plant profiles
- [ ] Lists all player assets in system
- [ ] Discovery date and discoverer shown

---

#### **Screen 7: Buildings**

**Route:** `/systems/:system_id/buildings` or `/buildings` (all buildings)

**Purpose:** List of player-owned buildings, optionally filtered by system.

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Building Detail |
| `s` | Manage staff |
| `r` | Repair (if damaged) |
| `t` | Filter by type (cycles: All → Refinery → Habitat → Extractor → ...) |
| `y` | Filter by system (cycles through systems with buildings) |
| `c` | Clear all filters |
| `/` | Search by name |

**Filter Behavior:**
- Filters persist until cleared
- URL updates to reflect filters: `/buildings?type=refinery&system=sy-vig`
- Count updates to show filtered total: `[3 of 7]`

**Success Criteria:**
- [ ] Type and system filters work independently
- [ ] URL reflects filter state (bookmarkable)
- [ ] Count shows filtered vs total

---

#### **Screen 8: Building Detail**

**Route:** `/buildings/:id`

**Purpose:** Full detail view of a single building.

**Keyboard:**
| Key | Action |
|-----|--------|
| `s` | Manage staff assignments |
| `r` | Repair building |
| `u` | Upgrade to next tier |
| `x` | Demolish (with confirmation) |

**Success Criteria:**
- [ ] Shows production I/O with efficiency %
- [ ] Staff slots with hire/assign actions
- [ ] Maintenance cost and breakdown risk visible

---

#### **Screen 9: Ships**

**Route:** `/ships`

**Purpose:** List of all player-owned ships.

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Ship Detail |
| `t` | Go to Trading submenu |
| `c` | Go to Combat submenu |

**Success Criteria:**
- [ ] Shows all ships with status indicators
- [ ] In-transit ships show destination and ETA
- [ ] Destroyed ships shown with salvage option

---

#### **Screen 10: Ship Detail**

**Route:** `/ships/:id`

**Purpose:** Full detail view of a single ship.

**Keyboard:**
| Key | Action |
|-----|--------|
| `n` | Set navigation destination |
| `c` | Manage cargo (load/unload) |
| `s` | Manage crew |
| `r` | Repair ship |
| `a` | Assign to route |

**Success Criteria:**
- [ ] Cargo manifest with load percentages
- [ ] Crew list with skill and wage
- [ ] Hardpoint loadout visible

---

#### **Screen 11: Trading (Routes)**

**Route:** `/ships/trading` or `/routes`

**Purpose:** Manage automated trading routes.

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Route Detail |
| `n` | Create new route |
| `d` | Delete route |

**Success Criteria:**
- [ ] All active routes with profit/hr
- [ ] Route creation wizard works
- [ ] Paused routes visually distinct

---

#### **Screen 12: Route Detail**

**Route:** `/routes/:id`

**Purpose:** View and edit a single trading route.

**Keyboard:**
| Key | Action |
|-----|--------|
| `e` | Edit route stops |
| `p` | Pause/resume route |
| `s` | Assign different ship |
| `d` | Delete route |

**Success Criteria:**
- [ ] Shows all stops with buy/sell orders
- [ ] Loop count and total profit displayed
- [ ] Edit mode allows reordering stops

---

#### **Screen 13: Combat**

**Route:** `/ships/combat`

**Purpose:** Combat-related ship management and battle logs.

**Success Criteria:**
- [ ] Lists combat-ready ships with hardpoints/marines
- [ ] Recent engagements with outcome
- [ ] Attack/defend actions available

---

#### **Screen 14: Workers**

**Route:** `/workers`

**Purpose:** Manage hired NPCs and browse the Recruiter for new hires.

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Worker Detail |
| `r` | Open Recruiter (hire new) |
| `f` | Fire selected worker |
| `a` | Assign to asset |

**Success Criteria:**
- [ ] All employed workers with assignment status
- [ ] Unassigned workers highlighted
- [ ] Fire confirmation prevents accidents

---

#### **Screen 15: Recruiter**

**Route:** `/workers/recruiter`

**Purpose:** Browse available NPCs for hire. Pool refreshes every 30-90 minutes.

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View full resume (employment history) |
| `h` | Hire selected NPC |
| `c` | Compare two NPCs side-by-side |

**Success Criteria:**
- [ ] Countdown timer to next pool refresh
- [ ] Employment history summary visible
- [ ] Hire deducts credits immediately

---

#### **Screen 16: Worker Detail / Resume**

**Route:** `/workers/:id`

**Purpose:** Full detail view of a worker including employment history (the resume).

**Success Criteria:**
- [ ] Full employment history with job outcomes
- [ ] Quirks/traits displayed
- [ ] Performance stats with current player

---

#### **Screen 17: About**

**Route:** `/about`

**Purpose:** Player stats, settings, and help.

**Success Criteria:**
- [ ] Player stats summary (credits, assets, playtime)
- [ ] Settings accessible
- [ ] Keyboard shortcuts reference

---

#### **Screen 18: Market**

**Route:** `/systems/:system_id/market`

**Purpose:** View buy/sell prices for a system's market. Only shows data for visited systems.

**Keyboard:**
| Key | Action |
|-----|--------|
| `b` | Buy commodity (opens quantity input) |
| `s` | Sell commodity |
| `c` | Compare with other known markets |

**Success Criteria:**
- [ ] Buy/sell prices with spread visible
- [ ] Inventory levels shown
- [ ] Trend indicators (↑↓→)

---

#### **Screen Success Criteria (All Screens)**

**Done when:**
- [ ] All 18 screens render without error
- [ ] Navigation between screens works via menu clicks AND keyboard
- [ ] Breadcrumbs update correctly and are clickable
- [ ] `j`/`k` moves selection on every list screen
- [ ] `Enter` drills into detail on every list screen
- [ ] `Esc` goes back on every detail screen
- [ ] `H` returns to Inbox from anywhere
- [ ] `?` shows keyboard shortcut overlay
- [ ] All screens work with Turbo Frames (no full page reloads)
- [ ] Content panel updates in <100ms

**Fails if:**
- Any keyboard shortcut conflicts with browser defaults
- Navigation state desyncs from URL
- Back button doesn't work as expected
- Screen flickers or fully reloads on navigation

## **17. Fun Calibration (Final Test Phase)**

The final phase before launch. The agent tunes **data parameters only** — no code changes. If code changes are needed, a success criteria was missed earlier.

### **17.1. Calibration Philosophy**
* **Data, not code:** Adjust prices, rates, probabilities — not mechanics
* **Simulation-driven:** Run automated playthroughs, measure outcomes
* **Bounded iterations:** Maximum 50 calibration cycles to prevent infinite loops
* **Human validation:** Final "is this fun?" requires a human playtest

### **17.2. Tunable Parameters**

```ruby
# config/game_balance.yml
economy:
  starting_credits: 500
  loan_interest_rate: 0.15          # 15% per day
  bank_interest_rate: 0.02          # 2% per day
  price_variance_min: 0.5           # Prices can drop to 50%
  price_variance_max: 2.0           # Prices can spike to 200%
  exotic_price_spike_chance: 0.05   # 5% chance of 5x price
  
progression:
  days_per_game: 30
  starting_cargo_capacity: 50
  upgrade_cost_multiplier: 1.8
  
difficulty:
  bankruptcy_threshold: -1000       # Game over if debt exceeds this
  random_event_chance: 0.10         # 10% chance per travel
  pip_infestation_chance: 0.01      # 1% chance per asset per day
  
travel:
  base_fuel_cost: 1                 # Per coordinate
  fuel_price_variance: 0.3          # ±30%
```

### **17.3. Fun Metrics (Measurable Proxies)**

Run 1000 simulated games. Measure:

| Metric | Target Range | Too Low = | Too High = |
|--------|--------------|-----------|------------|
| **Win rate** | 30-50% | Too hard | Too easy |
| **Average game length** | 20-30 days | Dies too fast | Drags on |
| **Bankruptcy rate by day 10** | 10-25% | Too forgiving | Too punishing |
| **Comeback rate** | 15-30% | No hope once behind | Luck > skill |
| **Strategy diversity** | 3+ viable | Solved game | — |
| **Decisions per day** | 30-40 | Too passive | Decision fatigue |
| **Near-death recoveries** | 10-20% | No tension | Fake difficulty |
| **Dominant strategy usage** | <40% | — | Degenerate meta |

### **17.4. Simulation Strategy Types**

The calibration agent runs games using different AI strategies:

```ruby
STRATEGIES = {
  aggressive_trader: "Buy max, sell immediately at any profit",
  patient_trader: "Wait for 50%+ margins before selling", 
  diversified: "Never put more than 30% in one commodity",
  loan_shark: "Max loans, high risk high reward",
  conservative: "Never take loans, slow steady growth",
  explorer: "Prioritize discovering new systems",
  random: "Random valid actions (baseline)"
}
```

**Diversity check:** At least 3 strategies must have win rates within 15% of each other.

### **17.5. Calibration Loop**

```ruby
class FunCalibrator
  MAX_ITERATIONS = 50
  GAMES_PER_ITERATION = 1000
  
  def calibrate!
    iteration = 0
    
    while iteration < MAX_ITERATIONS
      results = simulate_games(GAMES_PER_ITERATION)
      metrics = calculate_metrics(results)
      
      if metrics_in_range?(metrics)
        log "✓ Fun calibration complete after #{iteration} iterations"
        return :success
      end
      
      adjustments = calculate_adjustments(metrics)
      
      if adjustments.empty?
        log "✗ No adjustments possible — may need design changes"
        return :stuck
      end
      
      apply_adjustments!(adjustments)
      iteration += 1
    end
    
    log "✗ Max iterations reached — manual review needed"
    return :max_iterations
  end
  
  private
  
  def calculate_adjustments(metrics)
    adjustments = {}
    
    # Win rate too low? Make it easier
    if metrics[:win_rate] < 0.30
      adjustments[:starting_credits] = +100
      adjustments[:loan_interest_rate] = -0.02
    end
    
    # Win rate too high? Make it harder
    if metrics[:win_rate] > 0.50
      adjustments[:starting_credits] = -50
      adjustments[:random_event_chance] = +0.02
    end
    
    # Games too short? Slow down death spiral
    if metrics[:avg_game_length] < 20
      adjustments[:bankruptcy_threshold] = -500
      adjustments[:loan_interest_rate] = -0.03
    end
    
    # Dominant strategy? Nerf it
    if metrics[:dominant_strategy_usage] > 0.40
      # Adjust based on which strategy is dominant
      adjustments[:price_variance_max] = +0.2  # More chaos
    end
    
    adjustments
  end
end
```

### **17.6. Success Criteria**

**Done when:**
- [ ] Win rate: 30-50%
- [ ] Average game length: 20-30 days
- [ ] Bankruptcy by day 10: 10-25%
- [ ] Comeback rate: 15-30%
- [ ] At least 3 viable strategies (within 15% win rate)
- [ ] Decisions per day: 2-5
- [ ] No single strategy wins >40% more than others
- [ ] Calibration completes in <50 iterations

**Measured by:**
```bash
bin/rails runner "FunCalibrator.new.calibrate!"
bin/rails runner "FunCalibrator.new.report_metrics"
```

**Fails if:**
- Calibration hits 50 iterations without converging → needs design review
- Any metric impossible to reach via data tuning → missing mechanic
- All strategies converge to same behavior → game is "solved"

**After automated calibration passes:**
- [ ] Human playtest: "Did you want to play again?" (yes = fun)
- [ ] Human playtest: "Was there a moment of tension?" (yes = engaging)
- [ ] Human playtest: "Did your choices feel meaningful?" (yes = agency)

### **17.7. Anti-Loop Safeguards**

```ruby
# Prevent oscillation
class FunCalibrator
  def apply_adjustments!(adjustments)
    adjustments.each do |param, delta|
      current = config[param]
      new_value = current + delta
      
      # Clamp to sane bounds
      new_value = new_value.clamp(PARAM_BOUNDS[param])
      
      # Prevent oscillation: don't reverse last change
      if @last_adjustments[param] && 
         @last_adjustments[param].sign != delta.sign
        log "⚠ Skipping oscillating adjustment for #{param}"
        next
      end
      
      config[param] = new_value
      @adjustment_history[param] << delta
    end
    
    @last_adjustments = adjustments
  end
end
```

**Hard limits:**
- Maximum 50 iterations total
- Each parameter has min/max bounds (can't go negative, can't exceed sanity)
- If same parameter oscillates 3x, lock it and move on
- If 5 consecutive iterations make no progress, abort with :stuck

## **18. Implementation Roadmap**

### **18.1. Phase 0: Foundation (Week 1-2)**
**Goal:** Rails app skeleton with core data models

**Deliverables:**
- [ ] Rails 8 app with PostgreSQL
- [ ] User authentication (passwordless)
- [ ] Core models: User, System, Ship, Building
- [ ] Procedural generation engine (Section 5.1)
- [ ] Basic CLI UI with Turbo/Stimulus

**Success Gate:** Can generate and display a procedural system

### **18.2. Phase 1: Core Loop (Week 3-4)**
**Goal:** Minimum playable tutorial

**Deliverables:**
- [ ] The Cradle (0,0,0) tutorial system
- [ ] Basic trading mechanics
- [ ] Ship movement and fuel
- [ ] Simple market with buy/sell
- [ ] Inbox notifications

**Success Gate:** Player can complete Phase 1 tutorial quest

### **18.3. Phase 2: Economy (Week 5-6)**
**Goal:** Dynamic economy and NPCs

**Deliverables:**
- [ ] NPC Recruiter system
- [ ] Shared recruit pools by level
- [ ] Employment and wages
- [ ] Market price dynamics
- [ ] Automated trading routes

**Success Gate:** Player can hire NPCs and run profitable routes

### **18.4. Phase 3: Expansion (Week 7-8)**
**Goal:** Multi-system gameplay

**Deliverables:**
- [ ] System discovery mechanics
- [ ] Building construction
- [ ] System ownership (dominion)
- [ ] Warp gate network
- [ ] Resource extraction

**Success Gate:** Player can discover, claim, and develop a system

### **18.5. Phase 4: Conflict (Week 9-10)**
**Goal:** PvP and asset decay

**Deliverables:**
- [ ] Combat system
- [ ] Pip infestations
- [ ] Asset breakdowns and maintenance
- [ ] System defense grids
- [ ] Trade vs Battle mode

**Success Gate:** Combat and decay mechanics create tension

### **18.6. Phase 5: Polish (Week 11-12)**
**Goal:** Fun calibration and launch prep

**Deliverables:**
- [ ] All 18 UI screens complete
- [ ] Performance optimization
- [ ] Fun calibration (Section 17)
- [ ] Starter quests for all 4 galaxies
- [ ] End-game spawn hub mechanics

**Success Gate:** Game passes fun metrics, ready for players

### **18.7. Development Principles**

**Test-Driven:**
- Write tests for success criteria first
- Each phase has automated gate tests
- No phase proceeds until tests pass

**Playable at Every Phase:**
- Each phase delivers a complete loop
- Always have a working game
- Iterate based on play feedback

**Performance First:**
- Target <50ms for all operations
- Profile and optimize each phase
- Never compromise on speed

### **18.8. Success Metrics**

**Technical:**
- [ ] All procedural generation <15ms
- [ ] All UI updates <100ms
- [ ] Support 10,000 concurrent players
- [ ] <1GB database for 10k players

**Gameplay:**
- [ ] 30-50% win rate
- [ ] 20-30 day average game length
- [ ] 3+ viable strategies
- [ ] 30-40 meaningful decisions per day

**Launch Criteria:**
- [ ] All 18 screens implemented
- [ ] All success criteria passing
- [ ] Fun calibration converged
- [ ] Human playtest approval
