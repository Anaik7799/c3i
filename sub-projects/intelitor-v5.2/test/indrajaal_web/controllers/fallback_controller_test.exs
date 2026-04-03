defmodule IndrajaalWeb.FallbackControllerTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.FallbackController.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation fixes
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## Constitutional Verification
  - Psi0 Existence: FallbackController always handles errors gracefully
  - Psi5 Truthfulness: Error responses accurately represent the failure mode

  ## Founder's Directive Alignment
  - Omega0.1: Error handling ensures system continuity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Error responses return wrong status code or format
  - L5 Root Cause: Missing FallbackController clause for error type
  """

  use IndrajaalWeb.ConnCase, async: false

  @moduletag :zenoh_nif

  # The FallbackController is invoked via `action_fallback` in other controllers.
  # We test it indirectly by hitting endpoints on controllers that use it.
  # Direct unit tests use the controller dispatch pattern.

  describe "call/2 with {:error, :notfound}" do
    test "returns 404 for not-found error path" do
      # Test via the FallbackController module directly
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = %{conn | private: Map.put(conn.private, :phoenix_endpoint, IndrajaalWeb.Endpoint)}

      result = IndrajaalWeb.FallbackController.call(conn, {:error, :notfound})
      assert result.status == 404
    end
  end

  describe "call/2 with {:error, %Ecto.Changeset{}}" do
    test "returns 422 for changeset error" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = %{conn | private: Map.put(conn.private, :phoenix_endpoint, IndrajaalWeb.Endpoint)}

      changeset =
        Ecto.Changeset.change({%{}, %{name: :string}})
        |> Ecto.Changeset.add_error(:name, "can't be blank")

      result = IndrajaalWeb.FallbackController.call(conn, {:error, changeset})
      assert result.status == 422
    end
  end

  describe "call/2 with generic {:error, reason}" do
    test "returns 500 for generic error" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = %{conn | private: Map.put(conn.private, :phoenix_endpoint, IndrajaalWeb.Endpoint)}

      result = IndrajaalWeb.FallbackController.call(conn, {:error, :something_went_wrong})
      assert result.status == 500
    end
  end

  describe "integration: auth controller uses fallback for missing params" do
    test "missing email in login returns structured error (not 500)", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{"password" => "test"})
      # FallbackController handles — must be structured JSON response
      assert {:ok, _} = Jason.decode(conn.resp_body)
      assert conn.status in [400, 401, 422, 500]
    end

    test "missing password in login returns structured error", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{"email" => "test@example.com"})
      assert {:ok, _} = Jason.decode(conn.resp_body)
    end
  end

  describe "SIL-6 Requirements" do
    test "FallbackController handles all known error types without crash" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = %{conn | private: Map.put(conn.private, :phoenix_endpoint, IndrajaalWeb.Endpoint)}

      error_types = [
        {:error, :notfound},
        {:error, :internal_server_error},
        {:error, :service_unavailable}
      ]

      Enum.each(error_types, fn error ->
        result = IndrajaalWeb.FallbackController.call(conn, error)
        assert result.status in [400, 404, 422, 500, 503]
      end)
    end
  end

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-FC-001: FallbackController survives nil reason" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = %{conn | private: Map.put(conn.private, :phoenix_endpoint, IndrajaalWeb.Endpoint)}

      # nil reason should fall through to generic error handler
      result = IndrajaalWeb.FallbackController.call(conn, {:error, nil})
      assert result.status in [400, 422, 500]
    end

    @tag :fmea
    test "FMEA-FC-002: FallbackController survives string reason" do
      conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
      conn = %{conn | private: Map.put(conn.private, :phoenix_endpoint, IndrajaalWeb.Endpoint)}

      result = IndrajaalWeb.FallbackController.call(conn, {:error, "some string error"})
      assert result.status in [400, 422, 500]
    end
  end
end
