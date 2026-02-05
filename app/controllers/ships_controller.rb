class ShipsController < ApplicationController
  before_action :set_active_menu
  before_action :check_ship_arrivals
  before_action :set_ship, only: [:show, :repair, :assign_crew, :set_navigation, :upgrade]

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
    @current_system = System.find_by(id: params[:system_id])
    @purchasable_types = Ship.purchasable_types
    @user_credits = current_user.credits

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: "Purchase Ship" }
    ]
  end

  def create
    # Build ship without attaching to user association yet
    # (prevents validation issues when updating user credits)
    @ship = Ship.new(ship_params)
    @ship.user_id = current_user.id
    @current_system = System.find_by(id: params[:system_id]) || System.cradle

    # Set required defaults
    @ship.current_system = @current_system
    @ship.variant_idx ||= 0
    @ship.fuel = @ship.fuel_capacity  # Start fully fueled

    # Validate params before cost check to avoid ArgumentError
    unless Ship::HULL_SIZES.include?(@ship.hull_size)
      @ship.errors.add(:hull_size, "is not a valid hull size")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    unless Ship::RACES.include?(@ship.race)
      @ship.errors.add(:race, "is not a valid race")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    # Validate affordability before attempting save
    unless current_user.can_afford_ship?(hull_size: @ship.hull_size, race: @ship.race)
      @ship.errors.add(:base, "Insufficient credits to purchase this ship")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # Deduct cost from user
        current_user.deduct_ship_cost!(hull_size: @ship.hull_size, race: @ship.race)

        if @ship.save
          redirect_to @ship, notice: "Ship purchased successfully!"
        else
          # Rollback will restore credits
          raise ActiveRecord::Rollback
        end
      end
    rescue User::InsufficientCreditsError => e
      # Handle race condition where credits changed between check and deduct
      @ship.errors.add(:base, "Insufficient credits to purchase this ship")
      setup_new_view_vars
      render :new, status: :unprocessable_entity
      return
    end

    # If we get here without redirecting, save failed
    unless performed?
      setup_new_view_vars
      render :new, status: :unprocessable_entity
    end
  end

  def repair
    # TODO: Implement repair logic
    redirect_to @ship, notice: "Ship repaired!"
  end

  def upgrade
    attribute = params[:attribute]
    
    result = @ship.upgrade!(attribute, current_user)
    
    if result.success?
      respond_to do |format|
        format.html { redirect_to @ship, notice: "#{attribute.humanize} upgraded successfully!" }
        format.turbo_stream { 
          flash.now[:notice] = "#{attribute.humanize} upgraded!"
          render turbo_stream: [
            turbo_stream.replace("ship_upgrades", partial: "ships/upgrades", locals: { ship: @ship }),
            turbo_stream.replace("user_credits", partial: "shared/credits", locals: { user: current_user }),
            turbo_stream.replace("flash", partial: "shared/flash")
          ]
        }
      end
    else
      respond_to do |format|
        format.html { redirect_to @ship, alert: result.error }
        format.turbo_stream {
          flash.now[:alert] = result.error
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        }
      end
    end
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

  def check_ship_arrivals
    current_user.ships.in_transit.find_each(&:check_arrival!)
  end

  def set_active_menu(_unused = nil)
    @active_menu = :ships
  end

  def set_ship
    @ship = current_user.ships.find(params[:id])
  end

  def ship_params
    params.require(:ship).permit(:name, :race, :hull_size)
  end

  def setup_new_view_vars
    @purchasable_types = Ship.purchasable_types
    @user_credits = current_user.credits
    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Ships", path: ships_path },
      { name: "Purchase Ship" }
    ]
  end
end