defmodule IndrajaalWeb.Api.Mobile.Config.SitesControllerTest do
  @moduledoc """
  Tests for Mobile Sites Config API.
  PHASE T: Mobile controller test consolidated using MobileControllerTestFramework.
  """
  use IndrajaalWeb.MobileControllerTestFramework

  setup_mobile_test(IndrajaalWeb.Api.Mobile.Config.SitesController)

  describe "index" do
    @tag :integration
    test "lists all site configurations", %{authed_conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/sites")
      assert %{"status" => "success"} = json_response(conn, 200)
    end

    @tag :integration
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/sites")
      assert json_response(conn, 401)
    end
  end

  describe "show" do
    @tag :integration
    test "shows specific site configuration", %{authed_conn: conn, tenant: tenant} do
      config = insert(:site, tenant_id: tenant.id)
      conn = get(conn, ~p"/api/mobile/config/sites/#{config.id}")
      response = json_response(conn, 200)
      assert response["status"] == "success" or is_map(response["data"])
    end
  end
end
