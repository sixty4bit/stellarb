module FlavorText
  TEXTS = {
    docking: [
      "Welcome aboard. Try not to scratch the paint this time.",
      "Docking complete. The station didn't even flinch.",
      "You've parked. Somehow. Against all odds.",
      "Docking clamps engaged. Your insurance company breathes a sigh of relief.",
      "Another successful landing! The bar is on the floor and you still cleared it.",
      "The docking bay lights flicker. Even they're surprised you made it."
    ],
    fuel_low: [
      "Your fuel gauge is giving you the side-eye.",
      "Running on fumes and denial.",
      "Fuel status: thoughts and prayers.",
      "Your ship is one jump away from becoming a very expensive paperweight.",
      "The engine is making that sound again. You know the one.",
      "Pro tip: ships need fuel. Revolutionary, I know."
    ],
    purchase: [
      "Buy high, sell low. Classic you.",
      "Your accountant just felt a disturbance in the Force.",
      "Money well spent. Probably. Maybe. Let's not think about it.",
      "Transaction complete. Your wallet weeps quietly.",
      "Congratulations on your impulse purchase!",
      "Another fine addition to your collection of questionable decisions."
    ],
    combat_miss: [
      "You shot at the void and the void didn't even notice.",
      "Stormtrooper academy called. They want their diploma back.",
      "Miss! The enemy is starting to feel bad for you.",
      "Your laser bolts are exploring space on their own now.",
      "That shot was so off-target it has its own zip code.",
      "Swing and a miss! In space, no one can hear you whiff."
    ],
    combat_hit: [
      "Direct hit! Even a broken clock is right twice a day.",
      "BOOM! That's going on the highlight reel.",
      "Nice shot! Don't let it go to your head. Too late.",
      "Target hit. The enemy is reconsidering their career choices.",
      "Critical hit! Your ship does a little victory shimmy.",
      "You actually hit something! Screenshot this, no one will believe you."
    ],
    exploration_empty: [
      "Space: still mostly empty.",
      "You found a whole lot of nothing. Congratulations.",
      "The void stares back. It looks bored.",
      "Nothing here but dust, regret, and cosmic background radiation.",
      "Scanners report: nope.",
      "You've discovered the absence of anything interesting. Science!"
    ],
    exploration_discovery: [
      "Well well well, what do we have here?",
      "Your scanners are losing their mind. In a good way.",
      "Discovery! Quick, name it after yourself before anyone else does.",
      "Found something! And it's not another rock. Mostly.",
      "The universe coughed up something interesting for once.",
      "Alert: something actually worth your time detected."
    ],
    npc_hired: [
      "New crew member acquired. Lower your expectations accordingly.",
      "Welcome aboard! Please ignore the screaming. That's normal.",
      "You've hired someone. They haven't seen the ship yet.",
      "Recruitment successful. They'll learn to regret this soon enough.",
      "Fresh meat—I mean, valued team member onboarded.",
      "They said yes! Clearly they didn't read the reviews."
    ],
    npc_fired: [
      "They've been 'promoted to customer.'",
      "Another one bites the space dust.",
      "They're not fired, they're 'pursuing other opportunities.' In an escape pod.",
      "Severance package: one spacesuit, no helmet. (Just kidding. Mostly.)",
      "You've freed up a bunk. And a therapy slot.",
      "Gone but not forgotten. Actually, give it a week."
    ],
    trade_profit: [
      "Cha-ching! Your bank account does a little dance.",
      "Profit! Quick, spend it on something stupid.",
      "You're in the green! Savor this. It won't last.",
      "Money money money! Your ship smells like success. And exhaust fumes.",
      "A profitable trade? In THIS economy?",
      "The invisible hand of the market just gave you a high-five."
    ],
    trade_loss: [
      "Buy high, sell low. The classic strategy.",
      "Your profit margin has entered the shadow realm.",
      "That trade went about as well as the Hindenburg.",
      "Loss recorded. Your accountant sends their condolences.",
      "Financially, this was what experts call 'a bad move.'",
      "You've invested in negative growth. Very avant-garde."
    ],
    error_404: [
      "This page went out for milk and never came back.",
      "404: Page not found. Also not found: your sense of direction.",
      "The page you're looking for is in another castle.",
      "Error 404: The void between the stars, but make it web.",
      "This content has been abducted by aliens. We're negotiating.",
      "Nothing here. Much like your cargo hold."
    ],
    maintenance: [
      "Your ship is held together by duct tape and optimism.",
      "Maintenance complete. We found three bolts left over. Probably fine.",
      "Your mechanic is doing their best. Their best is concerning.",
      "Ship repaired! The weird noise is now a different weird noise.",
      "Fixed! Well, 'fixed.' Air quotes very much intended.",
      "Maintenance log updated. Prayers log also updated."
    ],
    empty_inbox: [
      "No messages. You're either very efficient or very unpopular.",
      "Inbox zero! Achievement unlocked. Or nobody likes you.",
      "Nothing here. The silence is deafening. And peaceful.",
      "Your inbox is emptier than deep space. And that's saying something.",
      "No new messages. The universe has nothing to say to you right now.",
      "All caught up! Time to stare into the void productively."
    ],
    no_ships: [
      "No ships? That's like a pirate without a parrot. Sad.",
      "Your fleet is currently a concept. An aspirational one.",
      "Zero ships. You're technically a pedestrian. In space.",
      "No ships in your fleet. Have you considered walking?",
      "Your hangar is so empty it echoes.",
      "Fleet status: imaginary. But dream big!"
    ],
    no_cargo: [
      "Your cargo hold echoes with the sound of lost profits.",
      "Nothing in the hold. It's basically a really expensive closet.",
      "Cargo: none. Just vibes and cosmic dust.",
      "Your cargo bay is emptier than a politician's promises.",
      "No cargo. Your ship is basically a very fast, very expensive taxi.",
      "The cargo hold is so empty, tumbleweeds would feel at home."
    ],
    level_up: [
      "LEVEL UP! You're slightly less terrible now!",
      "Ding! You've leveled up. The enemies level up too, but don't think about that.",
      "New level unlocked! Same you, bigger number.",
      "You've grown stronger! Your enemies have been notified.",
      "Level up! Your power is increasing. Your wisdom? Debatable.",
      "Achievement unlocked: Being Slightly Better Than Before."
    ],
    oregon_trail: [
      "You have died of space dysentery.",
      "Your oxen equivalent has broken an axle equivalent.",
      "You have contracted galactic cholera. Your frontier spirit is undimmed.",
      "Here lies your reputation. It died as it lived: poorly.",
      "You chose to ford the asteroid field. It did not go well.",
      "Your party has lost a wheel. You don't have wheels. Somehow, still a problem.",
      "A thief stole 3 units of antimatter in the night. Classic.",
      "You shot 2000 lbs of space bison but can only carry 100. Waste not, want not. Too late.",
      "Grandma has typhoid. She's also an AI. She's fine. She's not fine.",
      "The trail ahead is impassable. The trail behind is also impassable. Good luck.",
      "You traded 6 bullets for a tongue. Whose tongue? Don't ask.",
      "Tombstone reads: 'Pepperoni and space cheese. Here lies what's left of your dignity.'"
    ],
    chaos_event: [
      "Something chaotic happened. We'd explain, but honestly? We're confused too.",
      "CHAOS EVENT! The universe rolled a natural 1.",
      "Reality glitched. Please do not perceive.",
      "The cosmos just sneezed and things got weird.",
      "A wild chaos event appears! It's super effective!",
      "The RNG gods are feeling spicy today."
    ]
  }.freeze

  FALLBACK = [
    "Something happened. Probably.",
    "The universe shrugs.",
    "*elevator music plays*"
  ].freeze

  def self.for(context)
    (TEXTS[context] || FALLBACK).sample
  end
end
