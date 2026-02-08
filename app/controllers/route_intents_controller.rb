# frozen_string_literal: true

class RouteIntentsController < ApplicationController
  before_action :set_route
  before_action :set_stop_index
  before_action :set_intent_index, only: [:update, :destroy]

  # POST /routes/:route_id/stops/:stop_id/intents
  # Add a new intent to the stop
  def create
    @route.add_intent(
      stop_index: @stop_index,
      type: intent_params[:type],
      commodity: intent_params[:commodity],
      quantity: intent_params[:quantity]&.to_i,
      max_price: intent_params[:max_price]&.to_i,
      min_price: intent_params[:min_price]&.to_i
    )

    if @route.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_stops_route_path(@route) }
      end
    else
      render :error, status: :unprocessable_entity
    end
  end

  # PATCH /routes/:route_id/stops/:stop_id/intents/:id
  # Update an intent's properties
  def update
    attrs = intent_params.to_h.symbolize_keys.compact_blank
    attrs[:quantity] = attrs[:quantity].to_i if attrs[:quantity]
    attrs[:max_price] = attrs[:max_price].to_i if attrs[:max_price]
    attrs[:min_price] = attrs[:min_price].to_i if attrs[:min_price]

    @route.update_intent(
      stop_index: @stop_index,
      intent_index: @intent_index,
      **attrs
    )

    if @route.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_stops_route_path(@route) }
      end
    else
      render :error, status: :unprocessable_entity
    end
  end

  # DELETE /routes/:route_id/stops/:stop_id/intents/:id
  # Remove an intent from the stop
  def destroy
    @route.remove_intent(stop_index: @stop_index, intent_index: @intent_index)

    if @route.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_stops_route_path(@route) }
      end
    else
      render :error, status: :unprocessable_entity
    end
  end

  private

  def set_route
    @route = current_user.routes.find_by!(short_id: params[:route_id]) rescue current_user.routes.find(params[:route_id])
  end

  def set_stop_index
    @stop_index = params[:stop_id].to_i
  end

  def set_intent_index
    @intent_index = params[:id].to_i
  end

  def intent_params
    params.require(:intent).permit(:type, :commodity, :quantity, :max_price, :min_price)
  end
end
