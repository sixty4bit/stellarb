class ShipsController < ApplicationController
  before_action :set_active_menu
  before_action :set_ship, only: [:show, :repair, :assign_crew, :set_navigation]

  def index
    @ships = current_user.ships.includes(:current_system, :crew)

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships" }
    ]
  end

  def show
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: @ship.name }
    ]
  end

  def trading
    @ships = current_user.ships.where(status: [:docked, :in_transit])
    @routes = [] # TODO: Load user's trading routes

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: "Trading" }
    ]

    set_active_menu(:ships)
  end

  def combat
    @ships = current_user.ships.includes(:crew)
    @recent_battles = [] # TODO: Load combat logs

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: "Combat" }
    ]

    set_active_menu(:ships)
  end

  def new
    @ship = current_user.ships.build
    # TODO: Generate available ship types based on current system
  end

  def create
    @ship = current_user.ships.build(ship_params)
    if @ship.save
      redirect_to @ship, notice: "Ship purchased successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def repair
    # TODO: Implement repair logic
    redirect_to @ship, notice: "Ship repaired!"
  end

  def assign_crew
    # TODO: Implement crew assignment
    redirect_to @ship
  end

  def set_navigation
    # TODO: Implement navigation setting
    redirect_to @ship
  end

  private

  def set_active_menu
    super(:ships)
  end

  def set_ship
    @ship = current_user.ships.find(params[:id])
  end

  def ship_params
    params.require(:ship).permit(:name, :race, :hull_size)
  end
end