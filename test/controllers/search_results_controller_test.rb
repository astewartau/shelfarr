# frozen_string_literal: true

require "test_helper"

class SearchResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)
    @user = users(:one)
    @request_record = requests(:pending_request)
    @pending_result = search_results(:pending_result)
    @no_link_result = search_results(:no_link_result)
  end

  # === Authorization ===

  test "index denied for regular user when setting disabled" do
    SettingsService.set(:allow_user_request_approval, false)
    sign_in_as(@user)

    get request_search_results_path(@request_record)
    assert_redirected_to requests_path
    assert_match /permission/, flash[:alert]
  end

  test "index allowed for regular user when setting enabled" do
    SettingsService.set(:allow_user_request_approval, true)
    sign_in_as(@user)

    get request_search_results_path(@request_record)
    assert_response :success
  end

  test "index always allowed for admin regardless of setting" do
    SettingsService.set(:allow_user_request_approval, false)
    sign_in_as(@admin)

    get request_search_results_path(@request_record)
    assert_response :success
  end

  test "regular user cannot view other users requests" do
    SettingsService.set(:allow_user_request_approval, true)

    other_user = User.create!(username: "other", password: "Password123!", name: "Other", role: 0)
    other_request = Request.create!(book: @request_record.book, user: other_user, status: :pending, retry_count: 0)

    sign_in_as(@user)
    get request_search_results_path(other_request)
    assert_response :not_found
  end

  # === Select ===

  test "select denied for regular user when setting disabled" do
    SettingsService.set(:allow_user_request_approval, false)
    sign_in_as(@user)

    post select_request_search_result_path(@request_record, @pending_result)
    assert_redirected_to requests_path
  end

  test "select allowed for regular user when setting enabled" do
    SettingsService.set(:allow_user_request_approval, true)
    sign_in_as(@user)

    assert_difference -> { Download.count }, 1 do
      post select_request_search_result_path(@request_record, @pending_result)
    end

    @pending_result.reload
    assert @pending_result.selected?
  end

  test "select rejects result without download link" do
    SettingsService.set(:allow_user_request_approval, true)
    sign_in_as(@user)

    post select_request_search_result_path(@request_record, @no_link_result)
    assert_redirected_to request_search_results_path(@request_record)
    assert_match /cannot be downloaded/, flash[:alert]
  end

  # === Refresh ===

  test "refresh denied for regular user when setting disabled" do
    SettingsService.set(:allow_user_request_approval, false)
    sign_in_as(@user)

    post refresh_request_search_results_path(@request_record)
    assert_redirected_to requests_path
  end

  test "refresh allowed for regular user when setting enabled" do
    SettingsService.set(:allow_user_request_approval, true)
    sign_in_as(@user)

    assert_enqueued_with(job: SearchJob) do
      post refresh_request_search_results_path(@request_record)
    end

    assert_redirected_to request_path(@request_record)
  end
end
