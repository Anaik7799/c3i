defmodule IndrajaalWeb.Api.Mobile.Config.AnalyticsControllerTest do
  @moduledoc """
  Tests for Mobile Analytics Config API.
  PHASE T: Mobile controller test consolidated using MobileControllerTestFramework.
  """
  use IndrajaalWeb.MobileControllerTestFramework

  setup_mobile_test(IndrajaalWeb.Api.Mobile.Config.AnalyticsController)

  describe "index" do
    @tag :integration
    test "lists all analytics configurations", %{authed_conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/analytics")
      assert %{"status" => "success"} = json_response(conn, 200)
    end

    @tag :integration
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/analytics")
      assert json_response(conn, 401)
    end
  end

  describe "show" do
    @tag :integration
    test "shows specific analytics configuration", %{authed_conn: conn} do
      # Using a known analytics config endpoint
      conn = get(conn, ~p"/api/mobile/config/analytics/dashboard")
      response = json_response(conn, 200)
      assert response["status"] == "success" or is_map(response["data"])
    end
  end
end
