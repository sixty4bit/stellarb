# Screen Definitions

This document defines every screen in the StellArb UI. Each screen specifies what data is displayed, what actions are available, and what keyboard shortcuts apply.

## Tech Stack

- **Framework:** Rails 8 with Turbo + Stimulus
- **Rendering:** Server-rendered HTML, Turbo Frames for panel updates
- **Style:** Tailwind CSS, monospace font, terminal aesthetic
- **Layout:** Fixed left sidebar (menu), scrollable right panel (content)

## Global Navigation

**Keyboard (always active):**
| Key | Action |
|-----|--------|
| `j` | Move selection down |
| `k` | Move selection up |
| `Enter` | Select / drill into |
| `Esc` | Go back one level |
| `q` | Go back one level (alias) |
| `H` | Go to Home (Inbox) |
| `?` | Show keyboard shortcuts overlay |

**Menu Items:**
```
PlayerName
├── Inbox
├── Chat
├── Navigation
├── Systems
│   └── Buildings
├── Ships
│   ├── Trading
│   └── Combat
├── Workers
└── About
```

---

## 1. Inbox (Home Screen)

**Route:** `/inbox` (root redirects here)

**Purpose:** Activity feed showing all notifications, alerts, and messages from NPCs and systems.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox ◄────┤ INBOX                              [3 unread]    │
│   Chat       │ ─────────────────────────────────────────────────│
│   Navigation │ ● Route rt-vcs - down in profits $3              │
│   Systems    │   Gold more expensive than usual at Chug         │
│   Ships      │   2 minutes ago                                  │
│   Workers    │                                                  │
│   About      │ ● Ship sh-4em - DESTROYED                        │
│              │   Meteor strike. All crew lost. Cargo salvageable│
│              │   15 minutes ago                         [URGENT]│
│              │                                                  │
│              │ ○ New Hire Sam - arrived at Vigby                │
│              │   Will board sh-n3z when it arrives              │
│              │   1 hour ago                                     │
│              │                                                  │
│              │ ○ Building Refinery-7 - output full              │
│              │   Storage at 100%. Production halted.            │
│              │   3 hours ago                                    │
└─────────────────────────────────────────────────────────────────┘
```

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

**Actions:**
- Selecting a message drills into **Message Detail** (no modals)
- Messages link to relevant entity (ship, building, system)

---

## 2. Message Detail

**Route:** `/inbox/:id`

**Purpose:** Full view of a single notification with context and actions.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Inbox                                              │
│                                                                 │
│ ┤ Ship sh-4em - DESTROYED                                       │
│ │ ─────────────────────────────────────────────────────────────│
│ │                                                               │
│ │ From: Navigation System                                       │
│ │ Time: 2026-02-04 14:32:07 UTC                                │
│ │                                                               │
│ │ Your ship "Rusty Venture" (sh-4em) was struck by a meteor    │
│ │ while traversing the Kepler-7 asteroid belt.                 │
│ │                                                               │
│ │ CASUALTIES:                                                   │
│ │   - Navigator Zyx (Solari) - deceased                        │
│ │   - Engineer Bork (Krog) - deceased                          │
│ │                                                               │
│ │ SALVAGE AVAILABLE:                                            │
│ │   - 340 tons Iron (67% recoverable)                          │
│ │   - 12 tons Gold (100% recoverable)                          │
│ │                                                               │
│ │ ─────────────────────────────────────────────────────────────│
│ │ [S] Send salvage ship    [D] Dismiss    [V] View location    │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `s` | Send salvage ship (if applicable) |
| `d` | Dismiss message |
| `v` | View related entity (ship, building, system) |
| `Esc` | Back to Inbox |

---

## 3. Chat

**Route:** `/chat`

**Purpose:** Player-to-player messaging and guild chat.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox        │ CHAT                                           │
│   Chat ◄───────┤ ─────────────────────────────────────────────  │
│   Navigation   │ #general (Hub Nexus-7)                         │
│   Systems      │ ─────────────────────────────────────────────  │
│   Ships        │ [14:20] SpaceTrucker42: anyone selling iron?   │
│   Workers      │ [14:21] You: I've got 500t at Vigby, 12cr/t    │
│   About        │ [14:21] SpaceTrucker42: omw                    │
│                │ [14:35] xXVoidLordXx: pips got my titan again  │
│                │ [14:35] xXVoidLordXx: 3rd time this week       │
│                │                                                 │
│                │ ─────────────────────────────────────────────  │
│                │ > _                                             │
└─────────────────────────────────────────────────────────────────┘
```

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

---

## 4. Navigation

**Route:** `/navigation`

**Purpose:** Map view and travel controls. Shows current location, nearby systems, and active routes.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox        │ NAVIGATION                                     │
│   Chat         │ ─────────────────────────────────────────────  │
│   Navigation ◄─┤ Current Location: Vigby (3, 6, 0)              │
│   Systems      │ Star: Yellow Dwarf | Hazard: 12 | Controlled   │
│   Ships        │                                                 │
│   Workers      │ NEARBY SYSTEMS (fuel range):                   │
│   About        │ ─────────────────────────────────────────────  │
│                │   Chug        (3, 6, 3)   2 fuel   [visited]   │
│                │   Szaps       (3, 9, 0)   3 fuel   [visited]   │
│                │   Unknown-7a  (6, 6, 0)   3 fuel   [unvisited] │
│                │   Unknown-7b  (0, 6, 0)   3 fuel   [unvisited] │
│                │                                                 │
│                │ ACTIVE ROUTES:                                  │
│                │ ─────────────────────────────────────────────  │
│                │   rt-vcs: Vigby → Chug → Szaps → Vigby         │
│                │           Ship: Yamato | ETA: 4m | $34/hr      │
│                │                                                 │
│                │ [W] Warp to selected   [S] Scan   [R] Routes   │
└─────────────────────────────────────────────────────────────────┘
```

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

---

## 5. Systems

**Route:** `/systems`

**Purpose:** List of all known (visited) systems with key stats.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox        │ SYSTEMS                          [12 known]    │
│   Chat         │ ─────────────────────────────────────────────  │
│   Navigation   │ NAME          COORDS      STAR        HAZARD   │
│   Systems ◄────┤ ─────────────────────────────────────────────  │
│   └ Buildings  │ Vigby         (3,6,0)     Yellow      12       │
│   Ships        │ Chug          (3,6,3)     Red Dwarf   34       │
│   Workers      │ Szaps         (3,9,0)     Blue Giant  8        │
│   About        │ The Cradle    (0,0,0)     Yellow      0    [H] │
│                │ Nexus-7       (6,3,3)     Binary      45       │
│                │ Freeport      (9,6,6)     Neutron     78       │
│                │                                                 │
│                │ [H] = Home Hub   [C] = Controlled by you       │
│                │                                                 │
│                │ [Enter] View Details   [B] Buildings   [M] Market│
└─────────────────────────────────────────────────────────────────┘
```

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

---

## 6. System Detail

**Route:** `/systems/:id`

**Purpose:** Full detail view of a single system.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Systems                                            │
│                                                                 │
│ ┤ VIGBY                                        Coordinates: 3,6,0│
│ │ ─────────────────────────────────────────────────────────────│
│ │ Star: Yellow Dwarf                                           │
│ │ Hazard Level: 12 (Low)                                       │
│ │ Discovered By: You (2026-01-15)                              │
│ │ Controlled By: You                                           │
│ │                                                               │
│ │ PLANETS (4):                                                  │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Vigby I      Rocky/Small     Iron, Copper, Titanium        │
│ │   Vigby II     Gas Giant       -                              │
│ │   Vigby III    Oceanic/Medium  Kelpforest, Coralbloom        │
│ │   Vigby IV     Desert/Large    Gold, Platinum, Stellarium    │
│ │                                                               │
│ │ YOUR ASSETS HERE:                                             │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Ship: Yamato (docked)                                       │
│ │   Building: Refinery-7 (operational)                         │
│ │   Building: Habitation-3 (operational)                       │
│ │                                                               │
│ │ [M] Market   [B] Buildings   [P] Planets   [W] Warp here     │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `m` | View Market |
| `b` | View Buildings |
| `p` | View Planets (minerals/plants) |
| `w` | Warp here |

---

## 7. Buildings

**Route:** `/systems/:system_id/buildings` or `/buildings` (all buildings)

**Purpose:** List of player-owned buildings, optionally filtered by system.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Systems > Buildings                                │
│                                                                 │
│ ┤ BUILDINGS                                    [7 total]        │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Filter: [All Types ▼]  [All Systems ▼]           [Clear]     │
│ │ ─────────────────────────────────────────────────────────────│
│ │ NAME           SYSTEM    TYPE        STATUS      OUTPUT      │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Refinery-7     Vigby     Refinery    ● Online    340t/day    │
│ │ Habitation-3   Vigby     Habitat     ● Online    12 workers  │
│ │ Mine-Alpha     Chug      Extractor   ● Online    500t/day    │
│ │ Depot-2        Chug      Storage     ● Online    80% full    │
│ │ Shipyard-1     Szaps     Shipyard    ○ Offline   -           │
│ │ Lab-Zeta       Szaps     Research    ● Online    +2 data/hr  │
│ │ Starbase-HQ    Vigby     Admin Hub   ● Online    Governing   │
│ │                                                               │
│ │ ● = Online   ○ = Offline   ⚠ = Alert                         │
│ │                                                               │
│ │ [Enter] View Details   [S] Staff   [R] Repair                │
└─────────────────────────────────────────────────────────────────┘
```

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

---

## 8. Building Detail

**Route:** `/buildings/:id`

**Purpose:** Full detail view of a single building.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Buildings                                          │
│                                                                 │
│ ┤ REFINERY-7                                   Status: ● Online │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Type: Refinery (Krog)                                        │
│ │ Location: Vigby (3, 6, 0)                                    │
│ │ Tier: 2                                                       │
│ │ Condition: 87%                                                │
│ │                                                               │
│ │ PRODUCTION:                                                   │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Input:  Iron Ore (500t/day)                                │
│ │   Output: Refined Iron (340t/day)                            │
│ │   Efficiency: 68%                                            │
│ │                                                               │
│ │ STAFF (2/3 slots):                                           │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Eng. Bork (Krog)      Skill: 72   Wage: 45/day   [Assign]  │
│ │   Eng. Yara (Solari)    Skill: 65   Wage: 38/day   [Assign]  │
│ │   [Empty Slot]                                     [Hire]    │
│ │                                                               │
│ │ MAINTENANCE:                                                  │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Daily Cost: 120 credits                                    │
│ │   Last Repair: 3 days ago                                    │
│ │   Next Breakdown Risk: 4% / day                              │
│ │                                                               │
│ │ [S] Manage Staff   [R] Repair   [U] Upgrade   [X] Demolish   │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `s` | Manage staff assignments |
| `r` | Repair building |
| `u` | Upgrade to next tier |
| `x` | Demolish (with confirmation) |

---

## 9. Ships

**Route:** `/ships`

**Purpose:** List of all player-owned ships.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox        │ SHIPS                            [4 total]     │
│   Chat         │ ─────────────────────────────────────────────  │
│   Navigation   │ NAME        CLASS      LOCATION   STATUS       │
│   Systems      │ ─────────────────────────────────────────────  │
│   Ships ◄──────┤ Yamato      Cruiser    Vigby      ● Docked     │
│   ├ Trading    │ Enterprise  Transport  [in transit] → Chug    │
│   └ Combat     │ Nostromo    Frigate    Szaps      ● Docked     │
│   Workers      │ Serenity    Scout      [in transit] → Unknown  │
│   About        │                                                 │
│                │ ● Docked   → In Transit   ⚠ Alert   ✖ Destroyed│
│                │                                                 │
│                │ [Enter] Details   [T] Trading   [C] Combat     │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Ship Detail |
| `t` | Go to Trading submenu |
| `c` | Go to Combat submenu |

---

## 10. Ship Detail

**Route:** `/ships/:id`

**Purpose:** Full detail view of a single ship.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Ships                                              │
│                                                                 │
│ ┤ YAMATO                                       Status: ● Docked │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Class: Cruiser (Krog)                                        │
│ │ Location: Vigby (3, 6, 0)                                    │
│ │ Condition: 92%                                                │
│ │                                                               │
│ │ ATTRIBUTES:                                                   │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Cargo: 450/500 tons (90%)                                  │
│ │   Fuel: 78/100 units                                         │
│ │   Hull: 1840/2000 HP                                         │
│ │   Hardpoints: 4 (2 equipped)                                 │
│ │                                                               │
│ │ CARGO MANIFEST:                                               │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Iron: 200t        Gold: 50t       Titanium: 100t           │
│ │   Food: 100t                                                  │
│ │                                                               │
│ │ CREW (4/5 slots):                                            │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Nav. Zyx (Solari)     Skill: 81   Wage: 60/day             │
│ │   Eng. Grak (Krog)      Skill: 91   Wage: 85/day             │
│ │   Mar. Unit-7 (Myrm)    Skill: 55   Wage: 30/day             │
│ │   Mar. Unit-8 (Myrm)    Skill: 52   Wage: 30/day             │
│ │   [Empty Slot]                                                │
│ │                                                               │
│ │ [N] Navigate   [C] Cargo   [S] Staff   [R] Repair   [A] Route │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `n` | Set navigation destination |
| `c` | Manage cargo (load/unload) |
| `s` | Manage crew |
| `r` | Repair ship |
| `a` | Assign to route |

---

## 11. Trading (Routes)

**Route:** `/ships/trading` or `/routes`

**Purpose:** Manage automated trading routes.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Ships > Trading                                    │
│                                                                 │
│ ┤ TRADING ROUTES                               [3 active]       │
│ │ ─────────────────────────────────────────────────────────────│
│ │ ROUTE          STOPS                    SHIP       PROFIT    │
│ │ ─────────────────────────────────────────────────────────────│
│ │ rt-vcs         Vigby→Chug→Szaps→Vigby   Yamato     $34/hr    │
│ │ rt-abm         Affle→Bont→Murke→Affle   Enterprise $89/hr    │
│ │ rt-exp         Vigby→Unknown-7a→Vigby   Serenity   $12/hr    │
│ │                                                               │
│ │ [Enter] Route Detail   [N] New Route   [D] Delete Route      │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Route Detail |
| `n` | Create new route |
| `d` | Delete route |

---

## 12. Route Detail

**Route:** `/routes/:id`

**Purpose:** View and edit a single trading route.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Ships > Trading > Route                            │
│                                                                 │
│ ┤ ROUTE: rt-vcs                                                 │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Assigned Ship: Yamato (Cruiser)                              │
│ │ Status: Running (loop 47)                                    │
│ │ Profit/Hour: $34                                              │
│ │                                                               │
│ │ STOPS:                                                        │
│ │ ─────────────────────────────────────────────────────────────│
│ │ 1. Vigby                                                      │
│ │    BUY:  Iron (200t @ $10)                                   │
│ │    SELL: Gold (50t @ $150)                                   │
│ │                                                               │
│ │ 2. Chug                                                       │
│ │    BUY:  Gold (50t @ $120)                                   │
│ │    SELL: Iron (200t @ $15)                                   │
│ │                                                               │
│ │ 3. Szaps                                                      │
│ │    BUY:  Titanium (100t @ $25)                               │
│ │    SELL: -                                                    │
│ │                                                               │
│ │ [E] Edit Stops   [P] Pause   [S] Change Ship   [D] Delete    │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `e` | Edit route stops |
| `p` | Pause/resume route |
| `s` | Assign different ship |
| `d` | Delete route |

---

## 13. Combat

**Route:** `/ships/combat`

**Purpose:** Combat-related ship management and battle logs.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Ships > Combat                                     │
│                                                                 │
│ ┤ COMBAT                                                        │
│ │ ─────────────────────────────────────────────────────────────│
│ │ COMBAT-READY SHIPS:                                          │
│ │ ─────────────────────────────────────────────────────────────│
│ │ NAME        HARDPOINTS   MARINES   LOCATION   STATUS         │
│ │ Yamato      4 (2 wpns)   2         Vigby      Ready          │
│ │ Nostromo    2 (2 wpns)   0         Szaps      Ready          │
│ │                                                               │
│ │ RECENT ENGAGEMENTS:                                          │
│ │ ─────────────────────────────────────────────────────────────│
│ │ [2h ago] Nostromo vs Pirate Drone @ Szaps - VICTORY          │
│ │ [1d ago] Yamato vs Pirate Frigate @ Chug - VICTORY (damaged) │
│ │ [3d ago] Serenity vs Asteroid - DESTROYED                    │
│ │                                                               │
│ │ [Enter] Engagement Details   [A] Attack   [D] Defend         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 14. Workers (Recruiter)

**Route:** `/workers`

**Purpose:** Manage hired NPCs and browse the Recruiter for new hires.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox        │ WORKERS                          [8 employed]  │
│   Chat         │ ─────────────────────────────────────────────  │
│   Navigation   │ YOUR CREW:                                     │
│   Systems      │ ─────────────────────────────────────────────  │
│   Ships        │ NAME             CLASS      SKILL  ASSIGNMENT  │
│   Workers ◄────┤ Nav. Zyx         Navigator  81     Ship: Yamato│
│   About        │ Eng. Grak        Engineer   91     Ship: Yamato│
│                │ Eng. Bork        Engineer   72     Bldg: Refin-7│
│                │ Eng. Yara        Engineer   65     Bldg: Refin-7│
│                │ Mar. Unit-7      Marine     55     Ship: Yamato│
│                │ Mar. Unit-8      Marine     52     Ship: Yamato│
│                │ Gov. Calculus    Governor   78     Bldg: HQ    │
│                │ Nav. Krix        Navigator  44     [Unassigned]│
│                │                                                 │
│                │ [Enter] Details   [R] Recruiter   [F] Fire     │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View Worker Detail |
| `r` | Open Recruiter (hire new) |
| `f` | Fire selected worker |
| `a` | Assign to asset |

---

## 15. Recruiter

**Route:** `/workers/recruiter`

**Purpose:** Browse available NPCs for hire. Pool refreshes every 30-90 minutes.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Workers > Recruiter                                │
│                                                                 │
│ ┤ RECRUITER                          Pool refreshes in: 23 min │
│ │ ─────────────────────────────────────────────────────────────│
│ │ AVAILABLE FOR HIRE:                                          │
│ │ ─────────────────────────────────────────────────────────────│
│ │ NAME              CLASS      SKILL  WAGE    HISTORY          │
│ │ Grimbly Skunt     Navigator  67     42/day  ●●●○○ Clean      │
│ │ 7-Alpha-Null      Engineer   83     71/day  ●●○○○ 1 incident │
│ │ Smashgut Ironface Marine     59     35/day  ●●●●○ Clean      │
│ │ Cluster 447       Governor   72     55/day  ●●●○○ Clean      │
│ │ Fleezo Margin     Navigator  91     95/day  ●○○○○ 2 incidents│
│ │                                                               │
│ │ ● = Clean job   ○ = Incident/gap                             │
│ │                                                               │
│ │ [Enter] View Resume   [H] Hire   [C] Compare                 │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `Enter` | View full resume (employment history) |
| `h` | Hire selected NPC |
| `c` | Compare two NPCs side-by-side |

---

## 16. Worker Detail / Resume

**Route:** `/workers/:id`

**Purpose:** Full detail view of a worker including employment history (the resume).

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Workers                                            │
│                                                                 │
│ ┤ ENG. GRAK (Krog)                             Skill: 91       │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Class: Engineer                                               │
│ │ Race: Krog                                                    │
│ │ Wage: 85 credits/day                                         │
│ │ Status: Assigned to Ship: Yamato                             │
│ │ Quirks: Volatile, Gambler                                    │
│ │                                                               │
│ │ EMPLOYMENT HISTORY:                                          │
│ │ ─────────────────────────────────────────────────────────────│
│ │ • Titan Haulers — 2 months — "Creative differences"          │
│ │ • DeepCore Mining — 6 months — Reactor incident (T4)         │
│ │ • Freeport Station — 1 month — Mutual separation             │
│ │ • [Gap] — 8 months                                           │
│ │ • You — 3 months — Current                                   │
│ │                                                               │
│ │ PERFORMANCE WITH YOU:                                        │
│ │ ─────────────────────────────────────────────────────────────│
│ │   Breakdowns Prevented: 12                                   │
│ │   Breakdowns Caused: 2                                       │
│ │   Efficiency Modifier: +15%                                  │
│ │                                                               │
│ │ [A] Reassign   [R] Raise Wage   [F] Fire                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 17. About

**Route:** `/about`

**Purpose:** Player stats, settings, and help.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName                                                       │
│   Inbox        │ ABOUT                                          │
│   Chat         │ ─────────────────────────────────────────────  │
│   Navigation   │ PLAYER: SpaceTrucker42                         │
│   Systems      │ Credits: $45,230                               │
│   Ships        │ Systems Discovered: 12                         │
│   Workers      │ Systems Controlled: 2                          │
│   About ◄──────┤ Ships Owned: 4                                 │
│                │ Buildings Owned: 7                             │
│                │ Workers Employed: 8                            │
│                │ Play Time: 47h 23m                             │
│                │                                                 │
│                │ [S] Settings   [K] Keyboard Shortcuts   [H] Help│
│                │ [L] Logout     [Q] Quit                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 18. Market

**Route:** `/systems/:system_id/market`

**Purpose:** View buy/sell prices for a system's market. Only shows data for visited systems.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│ PlayerName > Systems > Vigby > Market                           │
│                                                                 │
│ ┤ MARKET: VIGBY                         Last updated: Live     │
│ │ ─────────────────────────────────────────────────────────────│
│ │ COMMODITY      BUY PRICE   SELL PRICE   INVENTORY   TREND    │
│ │ ─────────────────────────────────────────────────────────────│
│ │ Iron           $12/t       $10/t        4,500t      ↓        │
│ │ Gold           $155/t      $150/t       120t        ↑        │
│ │ Titanium       $28/t       $25/t        890t        →        │
│ │ Food           $5/t        $4/t         12,000t     →        │
│ │ Fuel           $8/u        $7/u         3,400u      ↓        │
│ │ Stellarium     $2,400/t    $2,200/t     3t          ↑↑       │
│ │                                                               │
│ │ Your Cargo (Yamato docked here): 450t                        │
│ │                                                               │
│ │ [B] Buy   [S] Sell   [C] Compare Markets                     │
└─────────────────────────────────────────────────────────────────┘
```

**Keyboard:**
| Key | Action |
|-----|--------|
| `b` | Buy commodity (opens quantity input) |
| `s` | Sell commodity |
| `c` | Compare with other known markets |

---

## Success Criteria (All Screens)

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
