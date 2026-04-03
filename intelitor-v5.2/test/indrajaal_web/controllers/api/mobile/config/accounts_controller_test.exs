defmodule IndrajaalWeb.Api.Mobile.Config.AccountsControllerTest do
  @moduledoc """
  Tests for Mobile Accounts Config API.
  PHASE T: Mobile controller test consolidated using MobileControllerTestFramework.
  """
  use IndrajaalWeb.MobileControllerTestFramework

  setup_mobile_test(IndrajaalWeb.Api.Mobile.Config.AccountsController)

  describe "index" do
    @tag :integration
    test "lists all account configurations", %{authed_conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/accounts")
      assert %{"status" => "success"} = json_response(conn, 200)
    end

    @tag :integration
    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/mobile/config/accounts")
      assert json_response(conn, 401)
    end
  end

  describe "show" do
    @tag :integration
    test "shows specific account configuration", %{authed_conn: conn, user: user} do
      conn = get(conn, ~p"/api/mobile/config/accounts/#{user.id}")
      response = json_response(conn, 200)
      assert response["status"] == "success" or is_map(response["data"])
    end
  end
end
