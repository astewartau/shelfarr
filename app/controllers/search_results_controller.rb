# frozen_string_literal: true

class SearchResultsController < ApplicationController
  before_action :require_approval_permission
  before_action :set_request
  before_action :set_search_result, only: [:select]

  def index
    @search_results = @request.search_results.best_first
  end

  def select
    unless @search_result.downloadable?
      redirect_back fallback_location: request_search_results_path(@request),
                    alert: "This result cannot be downloaded (no download link available)"
      return
    end

    begin
      @request.select_result!(@search_result)
      redirect_back fallback_location: requests_path,
                    notice: "Download initiated for: #{@search_result.title}"
    rescue ArgumentError => e
      redirect_back fallback_location: request_search_results_path(@request), alert: e.message
    end
  end

  def refresh
    @request.search_results.destroy_all
    @request.update!(status: :pending)
    SearchJob.perform_later(@request.id)

    redirect_to request_path(@request),
                notice: "Search refreshed. Results will appear shortly."
  end

  private

  def require_approval_permission
    unless Current.user&.admin? || SettingsService.user_request_approval_allowed?
      redirect_to requests_path, alert: "You don't have permission to manage search results."
    end
  end

  def set_request
    @request = if Current.user.admin?
      Request.find(params[:request_id])
    else
      Request.for_user(Current.user).find(params[:request_id])
    end
  end

  def set_search_result
    @search_result = @request.search_results.find(params[:id])
  end
end
