---
title: StellArb PRD
created: 2026-02-04
tags: [stellarb, game-design, prd]
---

# **Product Requirement Document (PRD)**
Project Name: Stellar Arbitrage (Working Title)
Version: 0.2 (Updated)
Date: March 6, 2026

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

The Recruiter uses a three-table architecture for efficiency:

**Table 1: `recruits` (The Shared Pool)**
```
recruits
├── id
├── level_tier          # Which player levels see this recruit
├── race                # Vex, Solari, Krog, Myrmidon
├── class               # Governor, Navigator, Engineer, Marine
├── skill               # 1-100
├── base_stats          # JSONB - all procedural attributes
├── employment_history  # JSONB - generated resume (see 5.1.6)
├── chaos_factor        # 0-100, hidden from players
├── available_at        # When this recruit appears in rotation
└── expires_at          # When removed from pool (30-90 min window)
```

* **Generation:** Pool is pre-generated based on player count and class demand.
* **Rotation:** Recruits cycle in/out on random intervals (30-90 min).
* **Reuse:** Same recruit record shown to ALL players of that level tier.

**Table 2: `hired_recruits` (Permanent Copy)**
```
hired_recruits
├── id
├── original_recruit_id  # Reference to source (nullable, for audit)
├── race
├── class
├── skill
├── stats               # JSONB - frozen at hire time
├── employment_history  # JSONB - frozen at hire time
├── chaos_factor        # Frozen, still hidden
└── created_at          # Hire timestamp
```

* **Copy on Hire:** When a player hires, the recruit is **copied** to this table.
* **Immutable:** Stats are frozen forever. The recruit's history at hire time is preserved.
* **Decoupled:** Original recruit can expire from pool; hired copy persists.

**Table 3: `hirings` (Player ↔ Recruit Relationship)**
```
hirings
├── id
├── user_id
├── hired_recruit_id
├── custom_name         # Player can rename their crew
├── assignable_type     # "Ship" or "Building" (polymorphic)
├── assignable_id       # FK to ships or buildings table
├── hired_at
├── wage                # Current wage (can change over time)
├── status              # active, fired, deceased, retired, striking
└── terminated_at       # When employment ended (if applicable)
```

* **Polymorphic Assignment:** `assignable_type` + `assignable_id` allows assignment to Ships OR Buildings.
* **Mutable Data:** Only player-controlled data lives here (name, assignment, wage).
* **History:** Terminated hirings are kept for the player's employment history view.

**Why This Architecture:**
| Concern | Solution |
|---------|----------|
| Generation speed | Generate pool once, not per-player |
| Memory efficiency | Shared pool, not N copies |
| Deterministic rotation | Same recruits for same level = predictable |
| Stat immutability | Copy-on-hire freezes the recruit forever |
| Flexible assignment | Polymorphic handles ships/buildings |
| Player customization | Join table holds mutable fields only |

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

## **5. Infrastructure & Assets**

### **5.1. Procedural Generation Engine**

The universe, assets, and NPCs are generated deterministically from coordinate seeds — not stored until "realized" by player action.

#### **5.1.1. Core Principles**
* **Deterministic:** Same seed → same output, always. No randomness at generation time.
* **Lazy Realization:** Nothing exists in the database until a player discovers it.
* **Attribute-Based:** Assets are combinations of attributes, not hand-crafted designs.

#### **5.1.2. System Generation**
* **Input:** 3D coordinate tuple `(x, y, z)` where each axis is `0..999,999`
* **Seed Formula:** `SHA256(x || y || z)` → 256-bit seed
* **Output:** Deterministic system properties:
  * Star type (enum: Red Dwarf, Yellow, Blue Giant, etc.)
  * Planet count (0-12)
  * Resource distribution (mineral types + quantities)
  * Base market prices
  * Hazard level (0-100)

#### **5.1.3. Ship Generation**
* **Blueprint Pool:** Grows dynamically as player base increases.
* **Input:** Race + Hull Size + Variant Index + Location Seed
* **Attributes (all ships have these):**
  * Cargo Capacity (tons)
  * Fuel Efficiency (units per grid)
  * Maneuverability (turn rate)
  * Hardpoints (weapon slots)
  * NPC Crew Slots (min/max)
  * Maintenance Rate (credits/day)
  * Hull Points (durability)
  * Sensor Range (grids)
* **Variation:** A "Mark IV Hauler" in Galaxy A has different stats than one in Galaxy B (seed includes location).

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
  * Name (procedural, race-appropriate)
  * Race (Vex, Solari, Krog, Myrmidon)
  * Class (Governor, Navigator, Engineer, Marine)
  * Skill level (1-100)
  * Rarity tier (Common 70%, Uncommon 20%, Rare 8%, Legendary 2%)
  * Quirks (1-3 procedural traits)
  * Hidden Chaos Factor (0-100, never shown to player)
  * Employment History (see 5.1.6)
* **Pool Size:** Based on `(active_players * 0.3)` per class, minimum 10 per class.
* **Rotation:** New recruits generated every 30-90 minutes (random per level tier).

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

## **7. User Interface (UI)**
* Style: Text-Only / Command Line Interface (CLI).
* Feedback: "Just commands and information." No 3D rendering.
* Input: Players type commands or select options (e.g., `> warp to sector 4`, `> scan local`, `> buy 500 iron`).
* Visuals: Information is conveyed via text descriptions and data tables.

## **8. Technical Considerations**
* Database: Light schema. Only stores "Deltas" and Player Asset States.
* Asset Table: Needs flexible schema to handle procedurally generated attributes for thousands of unique ship/building types.

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

