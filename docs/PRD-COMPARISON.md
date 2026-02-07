# PRD Comparison: Original Vision vs Current Implementation
*Generated: February 6, 2026*

This document compares the [original PRD](./PRD.md) with the [current implementation state](./PRD-CURRENT.md).

---

## 1. What's Improved

Features from the original PRD that are now more complete, better implemented, or enhanced.

### 1.1 Minerals & Resources
| Aspect | Original | Current |
|--------|----------|---------|
| **Minerals** | Vague "minerals" with tier mentions | 60 detailed minerals across 5 tiers (Common→Exotic→Futuristic) |
| **Components** | Not specified | 45 components across 9 categories with manufacturing chains |
| **Factory Types** | Generic "refining" | 8 specialized factories (Basic, Electronics, Structural, Power, Propulsion, Weapons, Defense, Advanced) |

*Original Reference: Section 4.2 "Minerals (The Building Blocks)"*

### 1.2 Building Tier System
| Aspect | Original | Current |
|--------|----------|---------|
| **Tier Structure** | Mentioned 5 tiers with 1.8x/2.5x power law | Detailed cost/effect tables for all 4 building types |
| **Cost Progression** | Formula only | Specific credit costs (e.g., Mine: 10K→25K→50K→100K→250K) |
| **Effects** | Generic | Quantified (Mine T5: +150% supply, -25% price) |

*Original Reference: Section 10.2 "Building Generation Targets"*

### 1.3 Exploration System
| Aspect | Original | Current |
|--------|----------|---------|
| **Mechanics** | "Scanning" and "triangulate signatures" | Three exploration patterns: single direction, growing arcs, orbital |
| **Tracking** | Fog of war concept | `ExploredCoordinate` records per player |
| **Discovery** | First-discovered tag | First-visit notifications, discovery tracking |

*Original Reference: Section 3.2 "Phase 2: The Proving Ground"*

### 1.4 Market System
| Aspect | Original | Current |
|--------|----------|---------|
| **Pricing** | Base + Delta concept | Full formula with abundance modifiers, building effects, deltas |
| **Marketplace** | Implied | Required civic building with tiered fees (5%→1%) |
| **Inventory** | Mentioned | `MarketInventory` model with hourly restock jobs |

*Original Reference: Section 4.1 "The Static + Dynamic Model"*

### 1.5 Test Coverage
| Aspect | Original | Current |
|--------|----------|---------|
| **Tests** | Success criteria with benchmarks | 1,418+ tests across models, controllers, jobs, services |
| **Methodology** | Listed verification commands | TDD workflow: red → green → refactor |

*Original Reference: Section 5.1.7 "Success Criteria"*

---

## 2. What's Been Added

New features not in the original PRD.

### 2.1 System Auctions
**Description:** Inactive system owners can have their systems seized and auctioned to other players.

**Implementation:**
- `SystemOwnershipCheckJob` runs daily at 2am
- Tracks `owner_last_visit_at` for inactivity
- `SystemAuction` model with pending→active→completed lifecycle
- Players can bid on auctioned systems

*Not in original PRD - extends ownership mechanics.*

### 2.2 Pirate Encounters
**Description:** Ships traveling via conventional methods may encounter pirates.

**Implementation:**
- `PirateEncounterJob` triggers on ship arrival
- Encounter chance based on system hazard level
- Only affects non-warp travel

*Original only mentioned "Combat Rolls" in context of Marines.*

### 2.3 Mineral Discovery System
**Description:** Futuristic minerals must be discovered before appearing in markets.

**Implementation:**
- `MineralDiscovery` records track player unlocks
- Tied to specific star/system types (e.g., Stellarium from Neutron Stars)
- Creates exploration incentive

*Original had procedural resources but no discovery mechanic.*

### 2.4 Sound Effects
**Description:** Audio cues for in-game events.

**Implementation:**
- Audio system integrated into UI
- Event-triggered sounds

*Not mentioned in original PRD.*

### 2.5 Warp Gate Network (Simplified)
**Description:** Instant travel between connected warp gates.

**Implementation:**
- `WarpGate` model for system connections
- Flat 5 fuel cost
- Instant travel (no time cost)

*Original had warp gates but with different mechanics (see "What's Changed").*

---

## 3. What's Missing

Features from the original PRD that aren't implemented yet.

### 3.1 Tutorial Phases 2 & 3
**Original Vision:**
- **Phase 2 (Proving Ground):** Reserved systems, scanning tutorials, first building construction
- **Phase 3 (Emigration):** Choose from 5 Player Hubs, instant teleportation to frontier

**Current State:** Only Phase 1 (Cradle) is implemented. Players complete route setup but don't graduate to Proving Ground or receive Colonial Ticket.

*Original Reference: Sections 3.2 and 3.3*

### 3.2 Player Hubs & Spawn System
**Original Vision:**
- End-game players build "Colonial Beacons" to become spawn points
- 7-day Certification Audit (liquidity, opportunity, safety checks)
- Hub owners receive 5% tax on new players for 30 days
- Creates competition for "human resources" (newbies)

**Current State:** `PlayerHub` model exists but spawning, certification, and taxation not implemented.

*Original Reference: Section 5.4 "The End-Game: Becoming a Spawn Hub"*

### 3.3 NPC Quirks & Chaos System
**Original Vision:**
- Hidden "Chaos Factor" (0-100) determines failure probability
- Procedural quirks (Gambler, Cultist, etc.) with risk/reward
- Employment history as player's only clue to chaos factor
- Resume analysis ("Detective Game") to evaluate hires

**Current State:** Basic recruit properties exist (race, class, skill, chaos_factor, lifespan) but quirks, employment history, and the detective game aren't implemented.

*Original Reference: Sections 4.4.2, 5.1.5, 5.1.6, 15.5*

### 3.4 NPC Wage & Decay Mechanics
**Original Vision:**
- Exponential wage spiral for high-skill NPCs
- Unpaid NPCs sabotage before leaving
- Aging/retirement forces replacement scramble
- Poaching: hire NPCs away from other players

**Current State:** Basic NPC aging exists (`NpcAgeProgressionJob`), but wage demands, sabotage, and poaching aren't implemented.

*Original Reference: Section 4.4.3 "Management & Decay"*

### 3.5 NPC Classes & Role Effects
**Original Vision:**
- **Governor:** Tax yield variance, system administration
- **Navigator:** Fuel efficiency, event avoidance
- **Engineer:** Breakdown chance reduction
- **Marine:** Combat rolls, theft protection

**Current State:** Recruit classes exist but their mechanical effects on assets aren't implemented.

*Original Reference: Section 4.4.1 "Classes & Roles"*

### 3.6 System Entry Intentions
**Original Vision:**
- Players declare Trade Mode or Battle Mode on system entry
- Cannot switch while in-system (must leave and re-enter)
- Battle Mode engages defense grid immediately
- Strategic tradeoff: raiding forfeits trade access

**Current State:** Not implemented. All system entries are implicitly peaceful.

*Original Reference: Section 13.4 "System Entry Intentions"*

### 3.7 Combat System
**Original Vision:**
- Marines for boarding actions
- Combat rolls with NPC skill modifiers
- PvP raiding mechanics
- Defense infrastructure (grids, platforms)

**Current State:** Defense Platform building type exists but marked "not yet implemented." No combat mechanics.

*Original Reference: Sections 4.4.1, 9.3 (Krog traits)*

### 3.8 Racial Messaging ("The Petty Universe")
**Original Vision:**
- NPCs communicate in racial voice (Vex transactional, Solari cold, Krog aggressive, Myrmidon collective)
- "Mad Libs" complaint system for procedural humor
- Racial humor dynamics (cost-cutting jokes for Vex, literal jokes for Solari, etc.)

**Current State:** Messages exist but are generic. No racial voice or humor generation.

*Original Reference: Section 11 "Messaging & Notifications"*

### 3.9 Starter Quests (Race-Specific Galaxies)
**Original Vision:**
- 4 starter galaxies, each controlled by a race
- Unique NPC guides (Foreman Zorg, Broker Sly, Lead Researcher 7-Alpha, Cluster 8)
- Race-themed tutorial quests ("The Coffee Run," "Tax Evasion," etc.)

**Current State:** Generic Cradle tutorial. No race-specific onboarding.

*Original Reference: Section 14 "Starter Quests"*

### 3.10 The Pips (Infestation Race)
**Original Vision:**
- Never visually described ("The cute menace")
- Random infestations on poorly maintained assets
- 1% override chance on any failure
- Requires physical player presence to purge
- Procedural catastrophe descriptions ("Pips built a nest inside the focusing lens")

**Current State:** Basic pip infestation exists (`PipEscalationJob`) but physical presence requirement and elaborate procedural descriptions aren't implemented.

*Original Reference: Sections 9.5, 15 "The Catastrophe Mechanic"*

### 3.11 VI-Style Navigation
**Original Vision:**
- `j`/`k` for up/down, `Enter` to select, `Esc`/`q` to go back
- Hierarchical menu with inline submenus
- Breadcrumb navigation for deep drilling
- Desktop: menu left, content right

**Current State:** Menu exists with keyboard shortcuts but not full VI navigation. Breadcrumbs may be partial.

*Original Reference: Section 16 "User Interface"*

### 3.12 Flight Recorder Visualization
**Original Vision:**
- Permanent "Breadcrumb Trail" of player journey
- "Travel Map" showing lifetime path
- Heatmap generation for most traveled routes
- Query: "Where was I 3 months ago?"

**Current State:** `FlightRecord` model exists for ship movement but visualization (map, heatmap) not implemented.

*Original Reference: Section 12.3 "The Flight Recorder"*

### 3.13 System Visitor Logging
**Original Vision:**
- "Guest Book" logging who docked
- Hot/cold storage strategy (30-day fast access, then archive)
- Actions logged: Docked, Scanned, Attacked

**Current State:** `SystemVisit` exists for player visits but hot/cold archival strategy not implemented.

*Original Reference: Section 12.2 "The Guest Book"*

### 3.14 The Grant (Tutorial Reward)
**Original Vision:**
- Upon completing Phase 1, Colonial Authority provides credit lump sum
- Sufficient for Exploration Ship + crew

**Current State:** Phase 1 completion advances to Proving Ground but no credit grant.

*Original Reference: Section 3.1 "Phase 1: The Cradle"*

---

## 4. What's Changed

Design decisions that diverged from the original vision.

### 4.1 Warp Gate Mechanics
| Aspect | Original | Current |
|--------|----------|---------|
| **Travel Time** | Same as 1 coordinate per gate hop | Instant |
| **Fuel Cost** | Variable with owner fee split | Flat 5 fuel |
| **Chaining** | Must hop through each linked gate | Direct connection |
| **Strategy** | 10-gate chain = 10 × ship speed time | No time cost |

**Impact:** Current system is simpler but loses the "universe feels large" design goal.

*Original Reference: Section 13.2 "The Warp Gate Network"*

### 4.2 Ship Generation
| Aspect | Original | Current |
|--------|----------|---------|
| **Location Variance** | Same ship type varies by location seed | Fixed stats per race/hull |
| **Procedural Depth** | 200 unique hulls (4 races × 5 sizes × 10 variants) | Race + hull determines stats |
| **Attribute Generation** | Seeded ±20% cargo, ±15% fuel variance | Fixed with racial bonuses |

**Impact:** Simpler ship system, less variety within same hull type.

*Original Reference: Section 5.1.3 "Ship Generation"*

### 4.3 Building Construction
| Aspect | Original | Current |
|--------|----------|---------|
| **Time** | Implied construction time with drones | Instant |
| **Starbases** | Required expensive "Starbase Administration Hub" | No special building for ownership |

**Impact:** Faster building but less strategic depth around construction timing.

*Original Reference: Section 5.3.2 "The Claim Building"*

### 4.4 NPC Class System
| Aspect | Original | Current |
|--------|----------|---------|
| **Classes** | 4 defined: Governor, Navigator, Engineer, Marine | "Various specializations" (unspecified) |
| **Role Mechanics** | Each class affects specific asset stats | No class-based effects |

**Impact:** Current system is more flexible but loses the specialized crew management depth.

*Original Reference: Section 4.4.1 "Classes & Roles"*

### 4.5 Market Visibility
| Aspect | Original | Current |
|--------|----------|---------|
| **Data Access** | Only systems personally visited | Appears more accessible |
| **Staleness** | Last Known Price vs Live Data (presence-based) | Not explicitly tiered |

**Impact:** May reduce exploration incentive if market data is too accessible.

*Original Reference: Section 6.1 "Market Fog of War"*

### 4.6 Catastrophe Resolution
| Aspect | Original | Current |
|--------|----------|---------|
| **Pip Purge** | Physical player presence required | Escalation jobs run automatically |
| **Anti-AFK** | Cannot manage empire remotely if pips hit | No presence requirement |

**Impact:** Loses the "anti-automation" design goal for player engagement.

*Original Reference: Section 15.3 "The Hands-On Requirement"*

---

## Summary Statistics

| Category | Count |
|----------|-------|
| **Improved** | 5 major areas |
| **Added** | 5 new features |
| **Missing** | 14 unimplemented features |
| **Changed** | 6 design divergences |

### Priority Recommendations

**High Impact Missing Features:**
1. Tutorial Phases 2 & 3 (core progression)
2. NPC Quirks & Chaos System (hiring depth)
3. System Entry Intentions (strategic layer)
4. Racial Messaging (immersion)

**Design Divergences to Reconsider:**
1. Pip physical presence requirement (anti-AFK)
2. Warp gate time cost (universe scale)
3. NPC class effects (crew management)

---

*This comparison is intended to guide development priorities and identify feature gaps.*
