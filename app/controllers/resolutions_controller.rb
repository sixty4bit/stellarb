# frozen_string_literal: true

class ResolutionsController < ApplicationController
  def create
    incident = Incident.find(params[:incident_id])
    resolver = current_user.hired_recruits.find(params[:resolver_id])

    case params[:resolver_type]
    when "assistant"
      unless resolver.role == "assistant"
        redirect_back fallback_location: root_path, alert: "That worker is not your assistant."
        return
      end

      if resolver.on_cooldown?
        redirect_back fallback_location: root_path, alert: "Assistant is on cooldown."
        return
      end

      incident.resolve_with_assistant!(resolver)
      redirect_back fallback_location: root_path, notice: "✅ Assistant resolved the incident!"

    when "nearby"
      incident.resolve_with_nearby_npc!(resolver)

      if incident.resolved?
        redirect_back fallback_location: root_path, notice: "✅ Nearby crew member resolved the incident!"
      else
        redirect_back fallback_location: root_path, alert: "❌ Resolution failed! The situation has escalated."
      end

    else
      redirect_back fallback_location: root_path, alert: "Invalid resolver type."
    end
  end
end
