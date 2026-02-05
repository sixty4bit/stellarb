# frozen_string_literal: true

module RecruitersHelper
  # Color for rarity tier badge
  def rarity_color(tier)
    case tier.to_s.downcase
    when "legendary" then "yellow"
    when "rare" then "purple"
    when "uncommon" then "blue"
    else "gray"
    end
  end

  # Color for skill level
  def skill_color(skill)
    if skill > 80
      "lime"
    elsif skill > 60
      "white"
    else
      "gray"
    end
  end

  # Color for employment outcome
  def outcome_color(outcome)
    return "gray" unless outcome

    outcome_str = outcome.to_s.downcase

    if outcome_str.include?("incident") || outcome_str.include?("catastrophe") ||
       outcome_str.include?("error") || outcome_str.include?("breach")
      "orange"
    elsif outcome_str.include?("difference") || outcome_str.include?("separation") ||
          outcome_str.include?("concern")
      "yellow"
    else
      "gray"
    end
  end
end
