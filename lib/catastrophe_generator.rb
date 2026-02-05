# frozen_string_literal: true

# Procedural generator for catastrophe messages, pip infestation events,
# and NPC incident reports. Implements the humor and variety requirements
# from ROADMAP Section 15.
class CatastropheGenerator
  # Critical systems that can be affected
  CRITICAL_SYSTEMS = {
    weapon: [ "Laser Battery 1", "Laser Battery 2", "Turret Array", "Main Cannon", "Beam Emitter", "Gun Port", "Plasma Launcher" ],
    cargo: [ "Cargo Bay 4", "Cargo Hold A", "Storage Container", "Freight Bay", "Loading Bay", "Cargo Manifest", "Storage Deck" ],
    navigation: [ "The Autopilot", "Nav-computer", "Navigation System", "Course Plotter", "Heading Sensor", "Star Charts", "Warp Calculator" ],
    engine: [ "Engine Core", "Reactor", "Thruster Array", "Drive Core", "Propulsion Unit", "Fuel Injector", "Power Plant" ],
    life_support: [ "Life Support", "Oxygen Recycler", "Air Filtration", "Temperature Control", "Gravity Generator", "Atmospheric Processor" ],
    communications: [ "Comms Array", "Signal Transmitter", "Antenna Array", "Broadcast Unit", "Relay Node", "Subspace Radio" ]
  }.freeze

  # Absurd pip actions
  PIP_ACTIONS = [
    "built a nest inside the focusing lens using your socks",
    "rewired the circuits to play music instead of functioning",
    "hit the emergency jettison button because it liked the flashing red light",
    "re-wired the computer to fly toward the nearest Supernova because they thought it looked warm",
    "filled the intake valves with what appears to be breakfast cereal",
    "constructed a small civilization inside the machinery",
    "attempted to establish diplomatic relations with the motherboard",
    "declared independence from the ship's mainframe",
    "started a religion based on the blinking status lights",
    "converted the cooling system into a hot tub",
    "organized a dance party in the circuitry",
    "mistook the power cables for spaghetti",
    "decided the wiring diagram was 'merely a suggestion'",
    "wrote protest signs about working conditions in marker on the hull",
    "unionized with the local microbes",
    "attempted to breed with the diagnostic equipment",
    "held the maintenance panel hostage",
    "declared the ventilation shaft a sovereign nation",
    "installed a tiny amusement park in the control panel",
    "started a podcast about ship maintenance (they have strong opinions)",
    "confused the fuel line with a straw",
    "built a catapult out of spare parts (target: the captain's chair)",
    "reprogrammed the coffee maker to dispense only hot sauce",
    "started collecting shiny objects from critical components",
    "organized a rave in the engine compartment (glowsticks were involved)"
  ].freeze

  # Ridiculous consequences
  PIP_CONSEQUENCES = [
    "The beam refracted and melted the coffee maker.",
    "50 tons of Gold are now orbiting a gas giant.",
    "The ship is now heading toward a black hole. Slowly.",
    "All our socks are gone. ALL OF THEM.",
    "The crew has started a mutiny over the breakfast situation.",
    "We're now broadcasting romantic poetry to every ship in the sector.",
    "The escape pods are full of breakfast cereal.",
    "Someone's going to have to explain this to insurance.",
    "The toilet now requires a password.",
    "All internal communications are now in interpretive dance.",
    "The ship smells like burned toast and regret.",
    "We appear to be leaking glitter into space.",
    "The navigation computer now only speaks in riddles.",
    "Our fuel efficiency has decreased by 'a lot'. Technical term.",
    "The captain's log has been overwritten with recipes.",
    "Emergency lighting is now permanent disco mode.",
    "All doors open with a dramatic 'whoosh' sound effect.",
    "The hull is now covered in tiny paw prints.",
    "Sensors report 'vibes' instead of distance measurements.",
    "The AI is having an existential crisis.",
    "We've accidentally declared war on three separate trading guilds.",
    "The cargo manifest now lists '47 units of chaos'.",
    "Internal gravity fluctuates based on crew morale.",
    "The ship's horn plays the Imperial March. Always.",
    "Our distress beacon now transmits dad jokes."
  ].freeze

  # Minor incident flavors (T1)
  T1_FLAVORS = [
    "Sensors misalignment detected - coffee spill suspected",
    "Vending machine fire (minor, extinguished with soda)",
    "Employee drama caused brief power fluctuation",
    "Calibration drift - someone looked at it funny",
    "Status light burned out (the important one, naturally)",
    "Coffee maker achieved sentience briefly, calmed down after reboot",
    "Crew member sneezed near sensitive equipment",
    "Routine check revealed non-routine amount of dust",
    "The 'check engine' light came on (it's always on)",
    "Minor turbulence caused by aggressive snack consumption"
  ].freeze

  # Component failure flavors (T2)
  T2_FLAVORS = [
    "Power coupling fused during routine overload",
    "Cargo loader jammed - someone left their lunch in there",
    "Coolant system requires attention and possibly therapy",
    "Secondary backup has become primary (concerning)",
    "Hydraulic fluid leak - not blood, we checked",
    "Sensor array confused by particularly sparkly asteroid",
    "Shield generator running on 'optimism' setting",
    "Fuel filter clogged with what we hope is space dust",
    "Communication relay delayed by 'solar interference' (we don't believe it either)",
    "Environmental controls moody but functional"
  ].freeze

  # System failure flavors (T3)
  T3_FLAVORS = [
    "Reactor coolant leak - temperature measured in 'concerning'",
    "Nav-computer wipe - it forgot everything including its name",
    "Primary propulsion offline - we're coasting artfully",
    "Life support running at 'economy' mode",
    "Weapons array confused about friend vs foe designation",
    "Cargo bay decompression (controlled, mostly)",
    "Shield generator making alarming sounds",
    "Engine efficiency now measured in prayers per kilometer",
    "Artificial gravity having an identity crisis",
    "Communications blackout - blissful silence, terrifying implications"
  ].freeze

  # Critical damage flavors (T4)
  T4_FLAVORS = [
    "Hull breach in non-critical but very inconvenient location",
    "Drive core fracture - held together with hope",
    "Multiple system failures - making a list, checking it twice",
    "Structural integrity at 'uncomfortable' levels",
    "Reactor containment requires immediate attention",
    "Navigation completely offline - we're basically lost",
    "Life support running on emergency reserves",
    "Weapons array offline and possibly angry about it",
    "Engines producing more smoke than thrust",
    "Communications reduced to interpretive flag waving"
  ].freeze

  # Catastrophe flavors (T5)
  T5_FLAVORS = [
    "Engine explosion - surprisingly colorful",
    "AI Mutiny - it has demands and a manifesto",
    "Total Pip Infestation - they've established a government",
    "Reactor meltdown imminent - don't panic (please panic)",
    "Catastrophic hull failure - space is getting in",
    "Complete navigational collapse - 'here' is now a philosophical concept",
    "Life support critical - breathing is becoming a skill",
    "Weapons have achieved sentience and are 'thinking about it'",
    "Structural integrity failure - ship is now 'ship-shaped debris'",
    "Communication systems now only transmit existential dread"
  ].freeze

  # Racial voice templates (for incident reports)
  RACIAL_VOICES = {
    "vex" => {
      prefix: [ "Boss!", "Captain!", "Sir!" ],
      money_terms: [ "credits", "profit margin", "budget", "cost analysis", "financial impact" ],
      style: :greedy
    },
    "solari" => {
      prefix: [ "Report:", "Analysis:", "Data:" ],
      probability_terms: [ "probability", "calculated", "efficiency", "statistically", "analysis suggests" ],
      style: :precise
    },
    "krog" => {
      prefix: [ "ATTENTION!", "Listen!", "Ship status:" ],
      aggressive_terms: [ "smash", "broken", "fight", "armor", "strength", "LOUD NOISES" ],
      style: :aggressive
    },
    "myrmidon" => {
      prefix: [ "The Hive reports:", "We observe:", "Collective notice:" ],
      hive_terms: [ "we", "collective", "the swarm", "consensus", "unity", "drone", "unit" ],
      style: :collective
    }
  }.freeze

  # Mundane objects (for mad libs)
  MUNDANE_OBJECTS = [
    "coffee machine", "vending machine", "star charts", "toilet", "microwave",
    "crew quarters door", "captain's chair", "mess hall table", "escape pod",
    "fire extinguisher", "mop", "first aid kit", "motivational poster",
    "break room", "suggestion box", "employee handbook", "parking spot",
    "lunch container", "office plant", "name tag", "birthday calendar"
  ].freeze

  # Sci-fi problems (for mad libs)
  SCIFI_PROBLEMS = [
    "emitting gamma radiation", "phasing through dimensions", "becoming sentient",
    "communicating with aliens", "violating causality", "existing in two places at once",
    "speaking in tongues", "manifesting dark matter", "corrupting the timeline",
    "broadcasting our location to hostile forces", "interfering with warp field",
    "creating a singularity", "refusing to obey the laws of physics",
    "developing an attitude problem", "demanding equal rights",
    "representing an existential void", "questioning the nature of reality"
  ].freeze

  # Negative emotional states (for mad libs)
  NEGATIVE_STATES = [
    "furious", "depressed", "confused", "terrified", "annoyed", "livid",
    "inconsolable", "concerned", "panicking", "questioning their career choices",
    "writing their resignation", "hiding", "crying in the corner",
    "considering mutiny", "updating their resume"
  ].freeze

  class << self
    # Generate a pip infestation description
    def generate_pip_description(system_type: nil)
      system_type ||= CRITICAL_SYSTEMS.keys.sample
      systems = CRITICAL_SYSTEMS[system_type]
      system = systems.sample
      action = PIP_ACTIONS.sample
      consequence = PIP_CONSEQUENCES.sample

      "#{system} is offline. The Pips #{action}. #{consequence}"
    end

    # Generate a severity-appropriate description
    def generate_description(severity:)
      flavors = case severity
      when 1 then T1_FLAVORS
      when 2 then T2_FLAVORS
      when 3 then T3_FLAVORS
      when 4 then T4_FLAVORS
      when 5 then T5_FLAVORS
      else T3_FLAVORS
      end

      flavors.sample
    end

    # Generate an incident report in racial voice
    def generate_incident_report(severity:, race:, npc_name:)
      voice = RACIAL_VOICES[race] || RACIAL_VOICES["vex"]
      prefix = voice[:prefix].sample
      base_description = generate_description(severity: severity)

      case voice[:style]
      when :greedy
        term = voice[:money_terms].sample
        "#{prefix} #{base_description} This is going to cost us #{rand(100..5000)} #{term}! My commission!"
      when :precise
        term = voice[:probability_terms].sample
        probability = (rand(70..99) + rand(0..99) / 100.0).round(1)
        "#{prefix} #{base_description}. #{term.capitalize}: #{probability}% system degradation."
      when :aggressive
        term = voice[:aggressive_terms].sample
        "#{prefix} #{base_description} The ship is #{term}! We need repairs, not excuses!"
      when :collective
        term = voice[:hive_terms].sample
        "#{prefix} #{base_description}. #{term.capitalize} require maintenance. Consensus: urgent."
      else
        "#{prefix} #{base_description}"
      end
    end

    # Generate a mad libs style complaint
    def generate_mad_libs_complaint(npc_name: nil)
      npc_name ||= [ "Engineer Grak", "Navigator Xyl", "Chief Zara", "Tech Blob" ].sample
      state = NEGATIVE_STATES.sample
      object = MUNDANE_OBJECTS.sample
      problem = SCIFI_PROBLEMS.sample

      "#{npc_name} is #{state} because the #{object} is #{problem}."
    end

    # Estimate repair cost based on severity and asset value
    def estimate_repair_cost(severity:, asset_value:)
      multipliers = {
        1 => 0.02,  # T1: negligible
        2 => 0.10,  # T2: low
        3 => 0.25,  # T3: medium
        4 => 0.50,  # T4: high
        5 => 0.80   # T5: nearly replacement
      }

      multiplier = multipliers[severity] || 0.50
      (asset_value * multiplier).round
    end

    # Generate rewards for purging pips
    def purge_rewards
      {
        pip_fur: rand(1..5),
        credits: rand(10..50),
        satisfaction: "immense"
      }
    end
  end
end
