# frozen_string_literal: true

module EmigrationHelper
  # Returns CSS classes for security level badge styling
  # @param level [String] Security level (e.g., "High Security", "Moderate")
  # @return [String] Tailwind CSS classes
  def security_level_class(level)
    case level
    when "High Security"
      "bg-lime-800 text-lime-200"
    when "Moderate"
      "bg-yellow-800 text-yellow-200"
    when "Low Security"
      "bg-orange-800 text-orange-200"
    when "Lawless"
      "bg-red-800 text-red-200"
    else
      "bg-gray-800 text-gray-200"
    end
  end

  # Returns text color class based on security rating
  # @param rating [Integer] Security rating (0-100)
  # @return [String] Tailwind CSS color class
  def security_rating_color(rating)
    case rating
    when 80..100
      "text-lime-400"
    when 50..79
      "text-yellow-400"
    when 20..49
      "text-orange-400"
    else
      "text-red-400"
    end
  end
end
