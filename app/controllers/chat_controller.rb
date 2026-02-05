class ChatController < ApplicationController
  before_action :set_active_menu

  def index
    @channels = ["Global", "Trade", "Guild"]
    @current_channel = params[:channel] || "Global"
    @messages = [] # TODO: Load from chat system

    @breadcrumbs = [
      { name: current_user.name, path: root_path },
      { name: "Chat" }
    ]
  end

  def create
    # TODO: Implement chat message creation
    redirect_to chat_index_path
  end

  private

  def set_active_menu
    super(:chat)
  end
end