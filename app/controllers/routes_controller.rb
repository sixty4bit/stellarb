class RoutesController < ApplicationController
  before_action :set_active_menu
  before_action :set_route, only: [:show, :destroy, :pause, :resume, :edit_stops]

  def index
    @routes = current_user.routes.includes(:ships)

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: "Trading", path: trading_ships_path },
      { name: "Routes" }
    ]
  end

  def show
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: "Trading", path: trading_ships_path },
      { name: "Routes", path: routes_path },
      { name: @route.short_id }
    ]
  end

  def new
    @route = current_user.routes.build
    @available_ships = current_user.ships.where(status: :docked)
  end

  def create
    @route = current_user.routes.build(route_params)
    if @route.save
      redirect_to @route, notice: "Trade route created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @route.destroy
    redirect_to routes_path, notice: "Route deleted."
  end

  def pause
    @route.update!(status: :paused)
    redirect_to @route, notice: "Route paused."
  end

  def resume
    @route.update!(status: :active)
    redirect_to @route, notice: "Route resumed."
  end

  def edit_stops
    # TODO: Implement stop editing
    redirect_to @route
  end

  private

  def set_active_menu
    super(:ships)
  end

  def set_route
    @route = current_user.routes.find(params[:id])
  end

  def route_params
    params.require(:route).permit(:name, :ship_id, stop_ids: [])
  end
end