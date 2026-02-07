# frozen_string_literal: true

module RacesHelper
  RACE_DESCRIPTIONS = {
    "vex" => "Versatile and balanced. The everyman's choice.",
    "solari" => "Advanced sensor arrays. See everything, miss nothing.",
    "krog" => "Built like a tank. Reinforced hulls for the reckless.",
    "myrmidon" => "Efficient manufacturing. More ship for less credits.",
    "grelmak" => "Scrapyard genius. Better at everything... when it works.",
    "mechari" => "Precision robotics. Ultra-efficient but limited crew capacity."
  }.freeze

  def race_description(race)
    RACE_DESCRIPTIONS[race.to_s]
  end
end
