defmodule IndrajaalWeb.Api.Mobile.Config.VideoControllerTest do
  @moduledoc """
  Tests for Mobile Video Config API.
  PHASE T: Mobile controller test consolidated using MobileControllerTestFramework.
  """
  use IndrajaalWeb.MobileControllerTestFramework

  setup_mobile_test(IndrajaalWeb.Api.Mobile.Config.VideoController)

  describe "index" do
    @tag :integration
    test "lists all video configurations", %{authed_conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/video")
      assert %{"status" => "success"} = json_response(conn, 200)
    end

    @tag :integration
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/video")
      assert json_response(conn, 401)
    end
  end

  describe "show" do
    @tag :integration
    test "shows specific video configuration", %{authed_conn: conn, tenant: tenant} do
      config = insert(:camera, tenant_id: tenant.id)
      conn = get(conn, ~p"/api/mobile/config/video/#{config.id}")
      response = json_response(conn, 200)
      assert response["status"] == "success" or is_map(response["data"])
    end
  end
end
