# Exploration: Ship Movement & Efficient Discovery

**Date:** 2026-02-07
**Status:** Draft - Awaiting Review

## Problem Statement

The current exploration system operates as a remote scan/ping. When a player clicks a direction button (+X, +Y, etc.), the system finds the nearest unexplored coordinate in that direction and marks it as explored — but **the ship never moves**. The ship stays at its current system, and all subsequent explorations search from the same position.

This creates several problems:

1. **No sense of journey** — exploration feels like clicking a button on a dashboard, not piloting a ship through space
2. **No resource cost** — no fuel consumed, no travel time, no risk from pirate encounters
3. **Exploitable** — players can explore the entire grid from a single safe location with zero cost
4. **Inconsistent** — the rest of the game has meaningful ship travel (fuel, time, arrival events, combat), but exploration bypasses all of it
5. **Searching from a fixed position is slow** — the expanding shell algorithm searches outward from the same origin every time, meaning later explorations search through increasingly large explored regions before finding anything new

## Current Architecture

### Flow (View -> Controller -> Service)

1. **View** (`exploration/show.html.erb`): 6 direction buttons POST to `single_direction_exploration_path`
2. **Controller** (`exploration_controller.rb`): Maps direction to service name, calls `service.closest_unexplored(direction:)`, creates `ExploredCoordinate` record
3. **Service** (`exploration_service.rb`): Expands outward in Chebyshev shells from ship's current position, returns the closest unexplored coordinate where the primary axis matches the requested direction

### What's Missing

- No call to `Ship#travel_to!` or any movement method
- No fuel consumption
- No travel time
- No arrival processing (no `SystemVisit`, no pirate encounters, no discovery notifications)
- Ship's `current_system` never changes

### Existing Travel Infrastructure

The codebase already has robust ship travel mechanics:

- `Ship#travel_to!(destination, intent:)` — conventional travel with fuel cost, travel time, in-transit state
- `Ship#check_arrival!` — processes arrivals: records `SystemVisit`, applies intent, triggers pirate encounters, sends notifications
- `Ship#warp_to!(destination, intent:)` — instant travel via warp gates
- `FlightRecord` — travel logging (departure/arrival events)
- `SystemVisit` — visit tracking with price snapshots (fog of war)
- Fuel calculation: `distance * fuel_efficiency`
- Travel time: `(distance / (BASE_SPEED * speed_multiplier)).ceil` seconds

## Proposed Changes

### Core Change: Exploration Moves the Ship

When a player explores in a direction, the ship **physically travels** to the target coordinate. This means:

1. The exploration service finds the nearest unexplored coordinate (as it does now)
2. A system is "realized" at that coordinate if one exists procedurally (or the coordinate is marked as empty space)
3. The ship travels to that coordinate using existing travel mechanics
4. Standard arrival processing occurs (system visit, pirate check, discovery notification)
5. Subsequent explorations search from the **new position**

### The Coordinate-to-System Problem

Currently, ships travel between `System` records. But exploration targets raw coordinates that may not have a system. Two sub-problems need solving:

**A. What exists at the target coordinate?**

The procedural generation engine determines whether a system exists at any coordinate. When the ship arrives at an unexplored coordinate, the game "realizes" what's there:
- If procedural generation says a system exists: create the `System` record, ship docks there
- If it's empty space: mark the coordinate as explored (empty), ship is at those coordinates but not docked at any system

**B. Travel to coordinates without a System record**

The ship model already supports coordinate-based positioning (`location_x`, `location_y`, `location_z`) independent of `current_system`. This should be used for travel to empty space coordinates where no system exists.

### Fuel & Time Costs

Exploration travel uses the same fuel and time mechanics as regular travel:

- **Fuel cost**: `distance * fuel_efficiency` (Euclidean distance between current position and target coordinate)
- **Travel time**: Based on distance, speed, and maneuverability
- **Implication**: Players must manage fuel strategically. Deep exploration requires planning, not just button-mashing.

### Direction Filter Behavior

The current direction filter only constrains the primary axis (e.g., +X requires `x > current.x`). The other two axes are unconstrained. This means pressing "+X" might find a coordinate like `(3, 2, -1)` from `(0, 0, 0)` — all three coordinates change.

**Recommendation: Constrain to axis-aligned movement for Single Direction mode.**

When a player presses "+X", they expect to move along the X axis. The target should be the nearest unexplored coordinate along that axis only (y and z unchanged from current position). This makes the directional buttons intuitive and predictable:

- From `(0, 0, 0)`, pressing `+X` explores `(1, 0, 0)`, then `(2, 0, 0)`, etc.
- From `(3, 5, 2)`, pressing `+Y` explores `(3, 6, 2)`, then `(3, 7, 2)`, etc.
- Diagonal exploration is handled by the "Growing Arcs" and "Orbit" modes

This also makes the fuel cost predictable — axis-aligned moves always cost exactly 1 unit of distance per step.

## Efficient Exploration Strategy

### The Problem with Naive Exploration

The grid is 19x19x19 = 6,859 coordinates. Visiting every one would be tedious and expensive. A naive approach (random walking, or always moving to the nearest unexplored) can lead to:

- Backtracking across already-explored regions
- Zigzag paths that waste fuel
- Players feeling lost without a sense of progress

### Recommended: Expanding Shell with Ship Movement

Since the ship now moves to each explored coordinate, the search naturally becomes more efficient:

1. **Ship at (0,0,0)**: Explore +X -> moves to (1,0,0)
2. **Ship at (1,0,0)**: Explore +X -> moves to (2,0,0)
3. **Ship at (2,0,0)**: Explore -Y -> moves to (2,-1,0)

Each search starts from the ship's current position, so the nearest unexplored coordinate is always close by. No more searching through huge explored regions from a fixed origin.

### Growing Arcs Mode: Outward Spiral

The Growing Arcs mode should use an expanding shell pattern from the ship's current position:

- Find the nearest unexplored coordinate in any direction
- Move the ship there
- Repeat

This naturally traces an outward spiral path, covering the grid efficiently without backtracking. The Chebyshev shell expansion already implements this — it just needs to move the ship.

### Orbit Mode: Ring Exploration

Orbit mode explores at a fixed distance from the origin, then expands:

- Find unexplored coordinates at the same orbital distance (distance from galactic center)
- Move to the nearest one
- When the ring is complete, expand to the next ring

This creates systematic coverage of concentric spherical shells.

### Sensor Range: See Before You Go

The ship's `sensor_range` attribute (from `ship_attributes`) should preview what's nearby:

- Show unexplored coordinates within sensor range on the exploration UI
- Indicate which ones likely contain systems (based on procedural peek)
- Let players choose which coordinate to explore next, rather than always auto-selecting

This adds strategic depth: players with better sensors can plan more efficient exploration routes.

## Game Design Considerations

### Why This Matters to Players

1. **Exploration has real cost** — fuel, time, and risk create meaningful decisions
2. **Position matters** — being deep in uncharted space means you're far from safe harbors
3. **Return trips** — players must plan how to get back, or build warp gates to create shortcuts
4. **Information asymmetry** — explored coordinates become valuable knowledge to trade with other players
5. **First discoverer** — physically arriving at a system earns the "First Discovered By" tag (already in PRD)

### Preventing Exploits

- **Can't explore from safety** — must physically be at the frontier
- **Fuel limits exploration range** — can't explore indefinitely without refueling
- **Travel time prevents spam** — each exploration step takes real time
- **Pirate encounters add risk** — unexplored high-hazard regions are dangerous

### Avoiding Tedium

- **Single Direction is fast** — axis-aligned moves are short (distance 1), predictable, and cheap
- **Growing Arcs is efficient** — always moves to nearest unexplored, minimizing wasted movement
- **Not every coordinate matters** — empty space is marked quickly and the ship moves on
- **System discoveries are rewarding** — finding a system triggers notifications, unlocks market data, and may earn first-discoverer bonuses
- **Warp gates as exploration infrastructure** — players can build gates at discovered systems to create fast-travel networks back to the frontier

### Edge Cases Gamers Will Find

1. **What if I run out of fuel in empty space?** — Need a rescue mechanic or emergency beacon. At minimum, prevent travel if fuel is insufficient.
2. **What if all adjacent coordinates are explored?** — The shell expansion handles this, but it may mean a long trip. Show the distance/cost before committing.
3. **Can I explore during travel?** — No. Ship must be docked or at a coordinate to initiate exploration.
4. **What about the ExploredCoordinate vs SystemVisit distinction?** — `ExploredCoordinate` marks coordinates checked (including empty space). `SystemVisit` only exists for realized systems. Both should be created as appropriate on arrival.
5. **What if two players explore the same coordinate simultaneously?** — `System.discover_at` uses `find_or_create_by`, which handles this. `ExploredCoordinate.mark_explored!` similarly uses `find_or_create_by!`. First player to arrive gets the "First Discovered By" tag.

## Warp Gate Auto-Linking via Directional Pyramids

### The 6-Pyramid Segmentation

When a warp gate is installed at a system, it needs to connect to nearby systems that also have warp gates. Rather than connecting to the N closest (which might all be in one direction), the space around the system is divided into **6 directional pyramids** — one per cardinal direction.

A coordinate belongs to a pyramid when that axis has the **dominant delta**:

```
dx = target.x - gate.x
dy = target.y - gate.y
dz = target.z - gate.z

+X pyramid:  dx > 0  AND  dx >= |dy|  AND  dx >= |dz|
-X pyramid:  dx < 0  AND |dx| >= |dy|  AND |dx| >= |dz|
+Y pyramid:  dy > 0  AND  dy >= |dx|  AND  dy >= |dz|
-Y pyramid:  dy < 0  AND |dy| >= |dx|  AND |dy| >= |dz|
+Z pyramid:  dz > 0  AND  dz >= |dx|  AND  dz >= |dy|
-Z pyramid:  dz < 0  AND |dz| >= |dx|  AND |dz| >= |dy|
```

Visualized as a cube cross-section:

```
         +Y
        /|\
       / | \
      /  |  \
  -X /   |   \ +X
     \   |   /
      \  |  /
       \ | /
        \|/
         -Y
```

Each pyramid's apex is at the gate's system. The boundaries are 45-degree planes where two axes have equal deltas.

### Auto-Link Algorithm

When a warp gate is installed at system S:

1. Query all other systems that have active warp gates
2. For each, calculate `(dx, dy, dz)` from S
3. Classify each into one of the 6 pyramids based on dominant axis
4. Within each pyramid, select the **closest** system (by Euclidean distance)
5. Create a `WarpGate` link between S and each selected system (up to 6 links)
6. The linked system's gate also gains a connection back (bidirectional)

**Tiebreaker for coordinates on pyramid boundaries** (where two axes have equal delta): assign to the axis that comes first in priority order `X > Y > Z`. This is deterministic and prevents coordinates from falling between pyramids.

**Re-linking**: When a new gate is installed, it may become the closest gate in some pyramid for an existing gate. Existing gates should re-evaluate their connections when a new neighbor appears. This keeps the network optimal as it grows.

### Network Topology

This creates a natural 3D mesh:

- Each gate connects to at most 6 neighbors (one per direction)
- Connections favor short hops over long jumps
- The network is spatially balanced — no direction is neglected
- As players explore and build more gates, the mesh becomes denser and more connected
- Frontier gates may only have 1-2 connections (toward explored space), creating natural "edge of the known galaxy" feel

## Bookmarks

### Player System Bookmarks

Players can bookmark any system they've visited:

- **Save**: Bookmark a system from the system view or navigation screen
- **Name**: Optional custom label (defaults to system name)
- **List**: View all bookmarks from the navigation screen
- **Remove**: Unbookmark from the bookmark list

### Data Model

```
Bookmark
  - user_id (references User)
  - system_id (references System)
  - label (string, optional — custom name)
  - created_at
  - unique constraint: [user_id, system_id]
```

Bookmarks are personal — each player manages their own list. A bookmark is just a saved reference; it doesn't grant any special access to the system.

## Multi-Hop Warp Routing

### "Warp To Bookmark" Flow

When a player selects a bookmarked system and chooses "Warp There":

1. **Build the warp gate graph** — all active `WarpGate` records form an undirected graph where systems are nodes and gates are edges
2. **Find shortest path** — BFS from the player's current system to the destination through the gate network (all hops cost the same: flat `WARP_FUEL_COST` per hop)
3. **Show the route** — display the path with hop count and total fuel cost before the player commits:
   ```
   Route to Verdant Gardens (3 hops, 15 fuel):
   The Cradle -> Mira Station -> Nexus Hub -> Verdant Gardens
   [Warp] [Cancel]
   ```
4. **Execute the route** — the ship warps through each gate in sequence (instant per hop, since warp travel is instant)
5. **Fuel check upfront** — verify the ship has enough fuel for ALL hops before starting. Don't strand them mid-route.

### Pathfinding Details

- **Algorithm**: BFS (unweighted graph — each hop costs the same)
- **No route found**: If the destination isn't reachable via the gate network, show "No warp route available. Destination is not connected to the gate network." Player must travel conventionally or explore to build the network.
- **Fuel cost**: `hop_count * WARP_FUEL_COST` (currently 5.0 per hop)
- **Pirate encounters**: Skipped for warp travel (consistent with current `warp_to!` behavior)
- **System visits**: Each intermediate system should record a `SystemVisit` (the ship passes through)

### Why BFS Is Sufficient

The warp gate graph with 6-pyramid auto-linking creates a spatially-aware mesh where:
- Short paths in the graph correspond to short distances in space
- Each hop connects to the nearest neighbor in each direction
- The graph stays sparse (at most 6 edges per node)
- BFS on a sparse graph is fast, even with thousands of systems

Dijkstra or A* would only be needed if hop costs varied (e.g., fuel cost per hop scaled with distance). With flat costs, BFS gives the optimal path.

## Success Criteria (Updated)

### Exploration Movement
- [ ] Pressing a direction button initiates ship travel to the target coordinate
- [ ] Ship consumes fuel proportional to distance traveled
- [ ] Ship enters `in_transit` state with a real `arrival_at` time
- [ ] On arrival, a `SystemVisit` is recorded if a system exists at the coordinate
- [ ] On arrival, an `ExploredCoordinate` is created for the coordinate
- [ ] On arrival, pirate encounter check runs (if system exists)
- [ ] Subsequent explorations search from the ship's new position
- [ ] Single Direction mode moves along one axis only (other coordinates unchanged)
- [ ] Player cannot explore without sufficient fuel
- [ ] Player cannot explore while ship is in transit
- [ ] Exploration UI shows current position updating after each exploration
- [ ] All existing exploration tests updated to reflect movement behavior

### Warp Gate Auto-Linking
- [ ] Installing a warp gate auto-links to nearest gated system in each of the 6 directional pyramids
- [ ] Pyramid assignment uses dominant-axis classification with X > Y > Z tiebreaker
- [ ] Existing gates re-evaluate connections when a new gate appears nearby
- [ ] Links are bidirectional (uses existing `WarpGate` model)
- [ ] At most 6 auto-links created per gate installation

### Bookmarks
- [ ] Players can bookmark a visited system with optional custom label
- [ ] Bookmarks listed on navigation screen
- [ ] Bookmarks can be removed
- [ ] Unique constraint prevents duplicate bookmarks

### Multi-Hop Warp Routing
- [ ] "Warp There" from bookmark shows route preview (path, hop count, fuel cost)
- [ ] Route found via BFS through the warp gate graph
- [ ] Fuel validated upfront for all hops before travel begins
- [ ] Ship warps through each hop in sequence
- [ ] System visits recorded at each intermediate system
- [ ] Clear message when no route exists

## Out of Scope (Future Work)

- Sensor range preview UI
- Rescue mechanics for stranded ships
- Selling exploration data to other players
- Exploration leaderboard integration with movement stats
- Variable warp costs (distance-based or owner fees)
- Manual warp gate linking (player-chosen connections beyond auto-link)
- Route optimization with waypoints
