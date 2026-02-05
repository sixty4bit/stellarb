# frozen_string_literal: true

module WorkersHelper
  include RecruitersHelper

  # Status color for worker assignment state
  def status_color(assigned)
    assigned ? "lime" : "orange"
  end

  # Format hiring status nicely
  def hiring_status_badge(hiring)
    return "text-gray-400" unless hiring

    case hiring.status
    when "active" then "text-lime-400"
    when "striking" then "text-yellow-400"
    when "fired", "deceased" then "text-red-400"
    else "text-gray-400"
    end
  end

  # Days remaining color
  def days_remaining_color(days)
    if days <= 10
      "red"
    elsif days <= 30
      "orange"
    elsif days <= 60
      "yellow"
    else
      "lime"
    end
  end

  # Effectiveness color
  def effectiveness_color(effectiveness)
    if effectiveness >= 0.9
      "lime"
    elsif effectiveness >= 0.7
      "yellow"
    elsif effectiveness >= 0.5
      "orange"
    else
      "red"
    end
  end
end
