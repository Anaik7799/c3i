defmodule IndrajaalWeb.Api.Mobile.Config.GuardToursControllerTest do
  @moduledoc """
  Tests for Mobile Guard Tours Config API.
  PHASE T: Mobile controller test consolidated using MobileControllerTestFramework.
  """
  use IndrajaalWeb.MobileControllerTestFramework

  setup_mobile_test(IndrajaalWeb.Api.Mobile.Config.GuardToursController)

  describe "index" do
    @tag :integration
    test "lists all guard tour configurations", %{authed_conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/guard-tours")
      assert %{"status" => "success"} = json_response(conn, 200)
    end

    @tag :integration
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/guard-tours")
      assert json_response(conn, 401)
    end
  end

  describe "show" do
    @tag :integration
    test "shows specific guard tour configuration", %{authed_conn: conn, tenant: tenant} do
      config = insert(:patrol_route, tenant_id: tenant.id)
      conn = get(conn, ~p"/api/mobile/config/guard-tours/#{config.id}")
      response = json_response(conn, 200)
      assert response["status"] == "success" or is_map(response["data"])
    end
  end
end
