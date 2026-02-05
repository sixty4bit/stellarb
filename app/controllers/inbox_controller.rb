class InboxController < ApplicationController
  before_action :set_active_menu
  before_action :set_message, only: [:show, :mark_read, :mark_unread, :destroy]

  def index
    @messages = current_user.messages.recent_first
  end

  def show
    @message.mark_read! if @message.unread?
  end

  def mark_read
    @message.mark_read!
    redirect_to inbox_index_path
  end

  def mark_unread
    @message.update!(read_at: nil)
    redirect_to inbox_index_path
  end

  def destroy
    @message.destroy
    redirect_to inbox_index_path, notice: "Message deleted"
  end

  private

  def set_message
    @message = current_user.messages.find(params[:id])
  end

  def set_active_menu
    super(:inbox)
  end
end
