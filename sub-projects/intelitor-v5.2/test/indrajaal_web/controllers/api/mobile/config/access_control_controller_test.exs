defmodule IndrajaalWeb.Api.Mobile.Config.AccessControlControllerTest do
  @moduledoc """
  Tests for Mobile Access Control Config API.
  PHASE T: Mobile controller test consolidated using MobileControllerTestFramework.
  """
  use IndrajaalWeb.MobileControllerTestFramework

  setup_mobile_test(IndrajaalWeb.Api.Mobile.Config.AccessControlController)

  describe "index" do
    @tag :integration
    test "lists all access control configurations", %{authed_conn: conn} do
      # Insert test data
      _configs = for _ <- 1..3, do: insert(:access_schedule)

      conn = get(conn, ~p"/api/mobile/config/access-control")
      assert %{"status" => "success"} = json_response(conn, 200)
    end

    @tag :integration
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/access-control")
      assert json_response(conn, 401)
    end
  end

  describe "show" do
    @tag :integration
    test "shows specific access control configuration", %{authed_conn: conn} do
      config = insert(:access_schedule)
      conn = get(conn, ~p"/api/mobile/config/access-control/#{config.id}")
      assert %{"status" => "success"} = json_response(conn, 200)
    end
  end
end
