class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [:update, :destroy]

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

  private

  def set_bookmark
    @bookmark = current_user.bookmarks.find(params[:id])
  end
end
