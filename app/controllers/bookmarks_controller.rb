class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [:update, :destroy, :warp_route]

  def index
    @bookmarks = current_user.bookmarks.includes(:system)
  end

  def create
    system = System.find(params[:system_id])

    unless SystemVisit.exists?(user: current_user, system: system)
      redirect_back fallback_location: bookmarks_path, alert: "You must visit a system before bookmarking it"
      return
    end

    bookmark = current_user.bookmarks.build(system: system, label: params[:label])
    if bookmark.save
      redirect_back fallback_location: bookmarks_path, notice: "System bookmarked"
    else
      redirect_back fallback_location: bookmarks_path, alert: bookmark.errors.full_messages.join(", ")
    end
  end

  def update
    if @bookmark.update(label: params[:label])
      redirect_to bookmarks_path, notice: "Bookmark updated"
    else
      redirect_to bookmarks_path, alert: @bookmark.errors.full_messages.join(", ")
    end
  end

  def destroy
    @bookmark.destroy
    redirect_to bookmarks_path, notice: "Bookmark removed"
  end

  def warp_route
    ship = current_user.ships.operational.first

    unless ship
      redirect_to bookmarks_path, alert: "No operational ship available"
      return
    end

    unless ship.current_system
      redirect_to bookmarks_path, alert: "Ship must be docked at a system to warp"
      return
    end

    route = WarpRouteService.find_route(ship.current_system, @bookmark.system)

    unless route
      redirect_to bookmarks_path, alert: "No warp route available to #{@bookmark.system.name}"
      return
    end

    if params[:confirm] == "true"
      result = ship.warp_route!(route)
      if result.success?
        redirect_to bookmarks_path, notice: "Warped to #{@bookmark.system.name} via #{route[:hops]} hop(s)!"
      else
        redirect_to bookmarks_path, alert: result.error
      end
    else
      # Show route preview
      @route = route
      @ship = ship
      render :warp_preview
    end
  end

  private

  def set_bookmark
    @bookmark = current_user.bookmarks.find(params[:id])
  end
end
