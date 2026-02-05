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

  # Color for chaos factor
  def chaos_color(chaos)
    if chaos >= 80
      "red"
    elsif chaos >= 50
      "orange"
    elsif chaos >= 20
      "yellow"
    else
      "lime"
    end
  end

  # CSS classes for quirk badges
  POSITIVE_QUIRKS = %w[meticulous efficient loyal frugal lucky vigilant dedicated precise resourceful calm].freeze
  NEGATIVE_QUIRKS = %w[lazy greedy volatile reckless paranoid saboteur alcoholic forgetful clumsy dishonest].freeze

  def quirk_badge_class(quirk)
    quirk_lower = quirk.to_s.downcase
    if POSITIVE_QUIRKS.include?(quirk_lower)
      "bg-lime-800 text-lime-200"
    elsif NEGATIVE_QUIRKS.include?(quirk_lower)
      "bg-red-800 text-red-200"
    else
      "bg-yellow-800 text-yellow-200"
    end
  end
end
