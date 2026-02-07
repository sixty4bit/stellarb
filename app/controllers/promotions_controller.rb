# frozen_string_literal: true

class PromotionsController < ApplicationController
  def create
    worker = current_user.hired_recruits.find(params[:worker_id])

    existing_assistant = current_user.hired_recruits.assistants.first
    if existing_assistant
      redirect_back fallback_location: worker_path(worker), alert: "You already have an assistant. Demote them first."
      return
    end

    worker.promote_to_assistant!(current_user)
    redirect_to worker_path(worker), notice: "#{worker.name} promoted to Assistant! ⭐"
  end

  def destroy
    worker = current_user.hired_recruits.find(params[:id])

    unless worker.role == "assistant"
      redirect_back fallback_location: worker_path(worker), alert: "This worker is not an assistant."
      return
    end

    worker.demote_to_crew!
    redirect_to worker_path(worker), notice: "#{worker.name} demoted to crew."
  end
end
