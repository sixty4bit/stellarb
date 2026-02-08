# frozen_string_literal: true

class RouteStopsController < ApplicationController
  before_action :set_route
  before_action :set_stop_index, only: [:update, :destroy, :reorder]

  # POST /routes/:route_id/stops
  # Add a new stop to the route
  def create
    system = System.find(stop_params[:system_id])
    @route.add_stop(system_id: system.id, system: system.name)

    if @route.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_stops_route_path(@route) }
      end
    else
      render :error, status: :unprocessable_entity
    end
  end

  # PATCH /routes/:route_id/stops/:id
  # Update a stop's system
  def update
    if stop_params[:system_id].present?
      system = System.find(stop_params[:system_id])
      @route.stops[@stop_index]["system_id"] = system.id
      @route.stops[@stop_index]["system"] = system.name
    end

    if @route.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_stops_route_path(@route) }
      end
    else
      render :error, status: :unprocessable_entity
    end
  end

  # DELETE /routes/:route_id/stops/:id
  # Remove a stop from the route
  def destroy
    @route.remove_stop(@stop_index)

    if @route.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_stops_route_path(@route) }
      end
    else
      render :error, status: :unprocessable_entity
    end
  end

  # PATCH /routes/:route_id/stops/:id/reorder
  # Move a stop to a new position
  def reorder
    to_index = params[:to].to_i
    @route.reorder_stop(from: @stop_index, to: to_index)

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
    @stop_index = params[:id].to_i
  end

  def stop_params
    params.require(:stop).permit(:system_id, :system)
  end
end
