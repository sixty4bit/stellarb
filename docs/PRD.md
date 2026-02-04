# **Product Requirement Document (PRD)**
Project Name: Stellar Arbitrage (Working Title)
Version: 0.2 (Updated)
Date: March 6, 2026

## **1. Executive Summary**
A massive multiplayer online strategy game that bridges the gap between the fast-paced, high-stakes trading of *Dope Wars* and the logistical depth of *Eve Online*, without the "spreadsheet fatigue." The game features a text-based (Command Line Interface) environment where players manage automated fleets, maintain decaying assets, and build infrastructure in a persistent, shared economy.

## **2. The World (Planetary Coordinate Space - PCS)**
* Scale: 1,000,000 x 1,000,000 x 1,000,000 grid (10^18 units).
* Generation: Deterministic Procedural Generation based on coordinate hash. No map data is stored until a player "Discovers" a system.
* The Starter Zones:
  * The Core: 6 distinct "Galaxies" (Clusters) containing 5-10 systems each in close proximity.
  * Starter Resources: These systems contain a defined "Starter Set" of minerals and buildings to facilitate early game learning.
  * Spawning: New players are added to one of the 6 galaxies at random.
* The Frontier: Infinite procedural space outside the Core. Deeper exploration requires larger ships with higher fuel capacity.
* Visibility:
  * 3D Bubble: Players only see stars within their current fuel range.
  * Fog of War: Unknown sectors are pitch black until scanned or data is purchased.
  * Navigation: Players are provided a list of valid directional commands/vectors based on their ship's capabilities.

## **3. Core Gameplay Loops**

### **3.1. Layer A: The Courier (Active / Online)**
* Action: Manual piloting via command inputs, deep space scanning, and market arbitrage.
* Navigation: Players choose from predefined maneuvers (e.g., "Burn", "Drift", "Slingshot"). Advanced ships unlock "Fancy" maneuvers for efficiency or speed.
* The Hook: Arriving at a system to find a price spike and selling before others arrive.

### **3.2. Layer B: The Tycoon (Strategic / Offline)**
* Automation: Programming ships with "Flight Manifests" to run complex loop routes.
* Maintenance: Assets (Ships/Buildings) run automatically but have a "Breakdown Chance." Players receive alerts via an in-game Inbox and must dispatch resources or commands to fix them.
* Decay: Markets saturate over time, and assets degrade, forcing active management.

### **3.3. Layer C: The Expedition (Exploration)**
* Depth: Bigger ships = Bigger Fuel Tanks = Deeper Exploration into the Void.
* Reward: Finding new systems unlocks new procedural resources and potential monopoly rights.

## **4. The Economy & Resources**

### **4.1. The "Static + Dynamic" Model**
* Base Price: Calculated mathematically via Seed.
* Price Delta: The only data stored in DB. Tracks inventory shifts.

### **4.2. Minerals (The Building Blocks)**
* Function: Used to construct Buildings and Ships.
* Distribution: Planets have specific mineral profiles. Starter galaxies have abundant "Basic" minerals.

### **4.3. NPCs (The Human Resource)**
* Definition: NPCs are a resource, governed like minerals. They are required to operate Ships and Buildings.
* Lifecycle:
  * Generation: NPCs are "spawned" or recruited from Habitation centers.
  * Decay: NPCs age, retire, or die, requiring constant replenishment (hiring/training).
  * Scarcity: High-level NPCs (Specialists) are difficult to obtain and essential for advanced assets.
* Starter Quests: Each Starter Galaxy has specific NPCs that guide new players via text-based quests.

## **5. Infrastructure & Assets**

### **5.1. Procedural Asset Generation**
* Growth: The list of available Ship and Building blueprints grows dynamically as the player base increases.
* Definition: Assets are not pre-designed manually but generated from a list of attributes:
  * *Example Attributes:* Cargo Capacity, Fuel Efficiency, Maneuverability, Hardpoints, NPC Crew Slots, Maintenance Rate.
* Uniqueness: A "Mark IV Hauler" in Galaxy A might have slightly different stats than one generated in Galaxy B, encouraging trade of blueprints and ships.

### **5.2. Building Ecosystem**
* Function: Buildings provide passive income, storage, or resource processing.
* Messaging: Buildings send status reports ("Storage Full", "Worker Strike", "Machinery Broken") to the player's Inbox.

## **6. User Interface (UI)**
* Style: Text-Only / Command Line Interface (CLI).
* Feedback: "Just commands and information." No 3D rendering.
* Input: Players type commands or select options (e.g., `> warp to sector 4`, `> scan local`, `> buy 500 iron`).
* Visuals: Information is conveyed via text descriptions and data tables.

## **7. Technical Considerations**
* Database: Light schema. Only stores "Deltas" and Player Asset States.
* Asset Table: Needs flexible schema to handle procedurally generated attributes for thousands of unique ship/building types.

## **4.3. NPC Mechanics (Human Resources)**
NPCs are the "Software" that runs the "Hardware" (Ships/Buildings). They are a finite, decaying resource that directly impacts the mathematical efficiency of assets.

### **4.3.1. Classes & Roles**
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

### **4.3.2. Quality & Traits**
* **Generation:** NPCs are generated with a "Rarity Tier" (Common, Uncommon, Rare, Legendary).
* **Traits:** Procedurally assigned "Quirks" that add risk/reward.
  * *Example (Trait: "Gambler"):* The NPC might randomly generate huge profits one week, then drain the account the next.
  * *Example (Trait: "Cultist"):* The NPC works for free but lowers the "Stability" of the planet.

### **4.3.3. Management & Decay**
* **The Wage Spiral:** Higher skill NPCs demand exponentially higher wages. If you fail to pay, they don't just leave—they sabotage.
* **Aging:** NPCs have a functional lifespan. A "Legendary Admiral" will eventually retire, forcing the player to scramble to find a replacement or watch their fleet efficiency plummet.
* **Poaching:** Players can attempt to hire NPCs away from other players by offering higher wages (Market PvP).

## **8. Racial Archetypes (The Builders)**
Assets are not generic; they are manufactured by specific civilizations. The "Manufacturer" attribute dictates the stat distribution and special abilities of Ships and Buildings.

### **Race A: The Vex (The Aggressive Traders)**
* *Archetype:* Ferengi / Hutt.
* *Focus:* Profit, Cargo Volume, Smuggling.
* *Ship Traits:* **"The Hauler."** Massive cargo holds, hidden compartments (smuggling bonus), weak shields, reliance on speed or bribery.
* *Building Traits:* Casinos, Trade Hubs, Black Markets. High income generation but high corruption/crime rates.

### **Race B: The Solari (The Logic Scientists)**
* *Archetype:* Vulcan / Asgard.
* *Focus:* Exploration, Sensors, Shields.
* *Ship Traits:* **"The Explorer."** Best-in-class Warp Drives, deep-space scanners, high shield regeneration, low hull armor. Expensive to repair.
* *Building Traits:* Research Labs, Sensor Arrays, Shield Generators. High energy consumption but provides the best Intel/Data.

### **Race C: The Krog (The Industrial Warriors)**
* *Archetype:* Klingon / Krogan.
* *Focus:* Durability, Mining, Boarding Actions.
* *Ship Traits:* **"The Brick."** Heavy armor plating, bonus Marine slots (for boarding), slow engines, high fuel consumption.
* *Building Traits:* Refineries, Shipyards, Bunkers. Extremely durable (hard to sabotage) but produce high pollution (lowers planet happiness).

### **Race D: The Myrmidon (The Hive Mind)**
* *Archetype:* Borg / Zerg / Insectoid.
* *Focus:* Mass Production, Cheap, Modular.
* *Ship Traits:* **"The Swarm."** Very cheap to buy, modular slots (can be refitted easily), low individual durability, "Organic Hull" (slow self-repair).
* *Building Traits:* Hydroponics, Clone Vats, Housing. Very efficient at supporting high populations/workforce.

### **8.1.5. The Unlisted Race: "The Pips"**
* **Archetype:** Tribbles / Gremlins / Minions.
* **Description:** Never visually described. Text references always evade specifics (e.g., *"The small, furry nightmare,"* *"The cute menace,"* *"Those things"*).
* **Behavior:** They are not built; they are an infestation. They randomly appear on ships/buildings that have low maintenance or visit "High Risk" bio-sectors.

## **8.2. Asset Generation Success Criteria**
The procedural engine must meet the following quantitative targets to ensure a diverse ecosystem.

### **8.2.1. Ship Generation Targets**
* **Total Unique Hulls:** ~200.
* **Formula:** `4 Races` x `5 Hull Sizes` (Scout, Frigate, Transport, Cruiser, Titan) x `10 Variants` = **200 Ships.**
* **Attribute Integrity Check:**
  * *Vex* ships must have 20% higher Cargo Capacity than the global average.
  * *Solari* ships must have 20% higher Sensor Range than the global average.
  * *Krog* ships must have 20% higher Hull Points than the global average.

### **8.2.2. Building Generation Targets**
* **Total Unique Structures:** ~100.
* **Formula:** `4 Races` x `5 Functions` (Extraction, Refining, Logistics, Civic, Defense) x `5 Tiers` = **100 Buildings.**
* **Attribute Integrity Check:**
  * Building Tiers must follow the Power Law (Cost increases by 1.8x, Output increases by 2.5x).
  * Racial buildings must require unique input materials (e.g., Solari buildings require more "Crystals/Electronics," Krog buildings require more "Steel/Concrete").

### **8.3. NPC Generation Targets**
* **Total Unique Variations:** Infinite (Procedural).
* **Racial Bonuses:**
  * *Vex NPC:* +10 Barter Skill / +5 Luck / Trait: "Greedy" (Higher Salary).
  * *Solari NPC:* +10 Science Skill / +5 Navigation / Trait: "Cold" (Low Morale impact).
  * *Krog NPC:* +10 Combat Skill / +5 Engineering / Trait: "Volatile" (High Strike chance).
  * *Myrmidon NPC:* +10 Agriculture / +5 Industry / Trait: "Hive Mind" (Must be hired in groups of 3+).

## **9. Messaging & Notifications (The Inbox)**
The Inbox is the primary feedback loop for the "Tycoon" layer. It is not just a chat log; it is an actionable dashboard.

### **9.1. Success Criteria: Functional**
* **Actionable Alerts:** Critical messages must include an inline command (e.g., "Engine Failure on Ship A" -> `[Cmd: Repair ($500)]`).
* **Filtering:** Players must be able to filter by "Urgent," "Trade," "Personnel," and "Discovery."
* **Capacity:** The inbox must handle high throughput (e.g., 50 automated ships reporting in simultaneously) by grouping similar messages (e.g., "7 Ships arrived at Hub A").

### **9.2. Success Criteria: Narrative (Racial Voice)**
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

### **9.3. Content Strategy: The "Petty Universe"**
While the economy is serious, the characters inhabiting it are flawed, petty, and bureaucratic. The Inbox serves as the comic relief by juxtaposing high-stakes sci-fi concepts with mundane, workplace complaints.

#### **9.3.1. The "Mad Libs" Complaint System**
System messages should use a slot-filling grammar to generate unique, often absurd scenarios.
* **Structure:** `[NPC_Name]` is `[Negative_State]` because `[Mundane_Object]` is `[SciFi_Problem]`.
* **Example Output:** *"Chief Engineer Grak is **furious** because the **coffee machine** is **emitting gamma radiation**."*
* **Example Output:** *"Navigator Xyl is **depressed** because the **star charts** represent **an existential void**."*

#### **9.3.2. Racial Humor Dynamics**
* **Vex (Greed):** Humor comes from absurd cost-cutting.
  * *Inbox:* "Captain, I replaced the escape pods with vending machines to maximize revenue per square foot. You're welcome."
* **Solari (Logic):** Humor comes from taking things too literally.
  * *Inbox:* "I have analyzed the concept of 'Fun'. It is inefficient. I have removed the crew lounge to increase productivity by 0.04%."
* **Krog (Violence):** Humor comes from over-reacting to small problems.
  * *Inbox:* "The toilet was clogged. I destroyed it with a plasma grenade. Glory to the Empire!"
* **Myrmidon (Hive):** Humor comes from a lack of individuality.
  * *Inbox:* "Unit #442 suggests we consume the passengers. They look high in protein. Awaiting consensus."

## **10. Data Persistence & Schema Strategy**
To manage the "Infinite" world while tracking granular player history, we employ a "Just-in-Time" realization strategy.

### **10.1. System Discovery Logic**
* **The "Realization" Event:** When a player scans a valid coordinate hash, the server "Realizes" the system.
* **Success Criteria:**
  * Create a row in the `systems` table with the fixed Seed ID.
  * Assign `discovered_by_player_id` (The "First Flag").
  * Generate the initial snapshot of the market/resources.
* **Notification:** Broadcast a "Galaxy First" event if it is a major find.

### **10.2. The "Guest Book" (Visitor Logging)**
Every system maintains a log of who has docked there.
* **Schema:** `system_visits` table.
* **Fields:** `system_id`, `player_id`, `timestamp`, `action` (e.g., "Docked", "Scanned", "Attacked").
* **Constraint:** To prevent database bloat, this table uses a "Hot/Cold" strategy. Recent visits (last 30 days) are fast-access; older visits are archived to cold storage logs.

### **10.3. The "Flight Recorder" (Player Movement History)**
Players have a permanent log of their journey ("The Breadcrumb Trail").
* **Visual Output:** Players can view a "Travel Map" showing their lifetime path through the stars.
* **Schema:** `flight_logs` table (TimeSeries).
* **Fields:** `player_id`, `origin_coords`, `dest_coords`, `fuel_consumed`, `timestamp`.
* **Success Criteria:**
  * Must support querying "Where was I 3 months ago?"
  * Must support "Heatmap" generation (showing most traveled routes).

### **10.4. Schema Architecture Success Criteria**
* **Asset Flexibility:** The `assets` table must use a JSONB (or EAV) column for `attributes` to allow for the infinite variations of procedurally generated ships/buildings without altering the table structure.
* **NPC State:** The `npcs` table must track `morale`, `age`, and `employer_history` to support the "Poaching" mechanic.

## **11. Travel Mechanics & Infrastructure**

### **11.1. Movement & Time**
* **The "Tick" Cost:** Movement is not instantaneous. It costs **Time** and **Fuel**.
* **Base Speed:** 60 Seconds per Coordinate Grid (Standard Engine).
* **Upgrade Cap:** High-tier engines/skills can reduce this to ~10 Seconds per Grid.
* **UI Feedback:** Players see a countdown timer during travel: `Status: En Route to [System X]... Arriving in 43s.`

### **11.2. The Warp Gate Network (The Highway)**
* **Function:** A constructible building that allows rapid travel to a "Nearest Neighbor" gate.
* **Cost:**
  * *Fuel Fee:* Charged to the traveler. Lower than the cost of manual flight.
  * *Distribution:* X% burned for travel, Y% goes to the Gate Owner's "Maintenance Fund," Z% is profit for the owner.
* **Time Cost:** Warping takes the same time as traveling **1 Coordinate** manually.
  * *Strategy:* A 10-gate chain covers massive distance but still takes `10 * Ship_Speed` seconds to traverse. This keeps the universe feeling large.
* **Limitation:** Gates must be "linked." You cannot warp to a gate 10,000 units away; you must warp to the *next* gate in the chain.

### **11.3. Navigation UI**
* **The "Short List":** The travel command `> warp` or `> move` displays a dynamic list:
  1. **Bookmarks:** (Player defined, e.g., "Home Base", "Good Mine").
  2. **Recent History:** Last 5 systems visited (Auto-generated).
  3. **Local Neighbors:** Systems reachable with current fuel.

## **12. Starter Quests (Onboarding)**
New players spawn in one of the 6 Core Galaxies. Each Galaxy has a "Flavor" and a specific NPC guide who introduces mechanics via "Petty Problems."

### **12.1. Galaxy A: "The Rusty Belt" (Krog Controlled)**
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

### **12.2. Galaxy B: "The Neon Spire" (Vex Controlled)**
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

### **12.3. Galaxy C: "The Void Lab" (Solari Controlled)**
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

### **12.4. Galaxy D: "The Hive" (Myrmidon Controlled)**
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

## **13. The "Catastrophe" Mechanic (Anti-Automation)**
While standard breakdowns can be fixed by spending credits remotely, **Catastrophic Events** require the player to physically travel to the asset to resolve them.

### **13.1. The 1% Rule (The Pip Factor)**
* **Trigger:** Every time an asset rolls for a standard failure (e.g., "Engine Breakdown"), there is a **1% Override Chance** that the cause is **Pips**.
* **The Effect:** The asset is **Disabled (Offline)**. It generates $0 income and cannot move until the player docks with it and executes the "Purge" command.

### **13.2. Procedural Catastrophe Generation (The Humor)**
Pip events must be elaborate, specific, and ridiculous.
* **Formula:** `[Critical_System]` disabled because Pips `[Absurd_Action]` resulting in `[Ridiculous_Consequence]`.
* **Example A (Weapon Failure):** *"Laser Battery 1 is offline. The Pips **built a nest inside the focusing lens** using your **socks**. The beam refracted and **melted the coffee maker**."*
* **Example B (Cargo Loss):** *"Cargo Bay 4 is empty. A Pip **hit the emergency jettison button** because it **liked the flashing red light**. 50 tons of Gold are now orbiting a gas giant."*
* **Example C (Navigation Error):** *"The Autopilot is locked. The Pips **re-wired the nav computer** to fly toward the nearest **Supernova** because they thought it looked **warm**."*

### **13.3. The "Hands-On" Requirement**
* **Why:** This prevents "AFK Empires." A player with 500 automated ships will eventually have 5 of them disabled by Pips. If they don't log in and fly out to "de-louse" their fleet, their empire slowly crumbles.
* **The Fix:**
  1. Player receives Inbox Alert: *"URGENT: Pip Infestation on Hauler Alpha-9."*
  2. Player must **fly their character** to the system where Hauler Alpha-9 is stranded.
  3. Player enters command: `> board ship` -> `> purge pips`.
  4. Reward: A small amount of "Pip Fur" (Tradeable luxury item? Fuel source?) and the ship returns to service.
