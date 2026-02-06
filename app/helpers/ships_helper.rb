module ShipsHelper
  def fuel_color_class(ship)
    return "text-lime-400" if ship.fuel_capacity.zero?

    percentage = ship.fuel.to_f / ship.fuel_capacity * 100

    if percentage < 10
      "text-red-500"
    elsif percentage < 25
      "text-yellow-500"
    else
      "text-lime-400"
    end
  end

  def fuel_bar_color_class(ship)
    return "bg-lime-500" if ship.fuel_capacity.zero?

    percentage = ship.fuel.to_f / ship.fuel_capacity * 100

    if percentage < 10
      "bg-red-500"
    elsif percentage < 25
      "bg-yellow-500"
    else
      "bg-lime-500"
    end
  end

  def health_color_class(ship)
    percentage = ship.hull_points.to_f / ship.max_hull_points * 100
    if percentage < 10
      "text-red-500"
    elsif percentage < 25
      "text-yellow-500"
    else
      "text-lime-400"
    end
  end
end
