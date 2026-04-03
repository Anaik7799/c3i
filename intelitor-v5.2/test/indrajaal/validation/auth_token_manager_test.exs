defmodule Indrajaal.Validation.AuthTokenManagerTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.AuthTokenManager.

  Tests GenServer-based authentication token management.
  Uses async: false because AuthTokenManager registers under its module name.
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.AuthTokenManager

  setup do
    # Stop any running instance before starting a fresh one
    case Process.whereis(AuthTokenManager) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, _pid} = start_supervised!(AuthTokenManager)
    :ok
  end

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(AuthTokenManager)
    end

    test "start_link/1 is exported" do
      assert function_exported?(AuthTokenManager, :start_link, 1)
    end

    test "authenticate/2 is exported" do
      assert function_exported?(AuthTokenManager, :authenticate, 2)
    end

    test "validate_token/1 is exported" do
      assert function_exported?(AuthTokenManager, :validate_token, 1)
    end

    test "revoke_token/1 is exported" do
      assert function_exported?(AuthTokenManager, :revoke_token, 1)
    end

    test "get_token_info/1 is exported" do
      assert function_exported?(AuthTokenManager, :get_token_info, 1)
    end

    test "list_active_sessions/0 is exported" do
      assert function_exported?(AuthTokenManager, :list_active_sessions, 0)
    end

    test "emergency_revoke_all/0 is exported" do
      assert function_exported?(AuthTokenManager, :emergency_revoke_all, 0)
    end
  end

  describe "authenticate/2" do
    test "returns ok tuple for valid api key (10+ alphanumeric chars)" do
      session_id = "session_#{System.unique_integer([:positive])}"
      result = AuthTokenManager.authenticate("validapikey123", session_id)
      assert match?({:ok, _}, result)
    end

    test "returns error for too-short api key" do
      session_id = "session_#{System.unique_integer([:positive])}"
      result = AuthTokenManager.authenticate("short", session_id)
      assert match?({:error, _}, result)
    end

    test "returns error for invalid api key format" do
      session_id = "session_#{System.unique_integer([:positive])}"
      result = AuthTokenManager.authenticate("key with spaces!", session_id)
      assert match?({:error, _}, result)
    end

    test "token info contains session_id" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, token_info} = AuthTokenManager.authenticate("validapikey123", session_id)
      assert token_info.session_id == session_id
    end

    test "token info contains api_key" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, token_info} = AuthTokenManager.authenticate("validapikey123", session_id)
      assert token_info.api_key == "validapikey123"
    end

    test "token info has created_at timestamp" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, token_info} = AuthTokenManager.authenticate("validapikey123", session_id)
      assert %DateTime{} = token_info.created_at
    end
  end

  describe "validate_token/1" do
    test "returns error for unknown session" do
      result = AuthTokenManager.validate_token("nonexistent_session_xyz_#{:rand.uniform(9999)}")
      assert result == {:error, :session_not_found}
    end

    test "returns ok for authenticated session" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id)
      result = AuthTokenManager.validate_token(session_id)
      assert match?({:ok, _}, result)
    end
  end

  describe "get_token_info/1" do
    test "returns error for unknown session" do
      result = AuthTokenManager.get_token_info("no_such_session_#{:rand.uniform(9999)}")
      assert result == {:error, :session_not_found}
    end

    test "returns token info for authenticated session" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id)
      result = AuthTokenManager.get_token_info(session_id)
      assert match?({:ok, %AuthTokenManager{session_id: ^session_id}}, result)
    end
  end

  describe "list_active_sessions/0" do
    test "returns a list" do
      result = AuthTokenManager.list_active_sessions()
      assert is_list(result)
    end

    test "returns empty list when no sessions authenticated" do
      result = AuthTokenManager.list_active_sessions()
      assert result == []
    end

    test "returns session info after authentication" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id)
      sessions = AuthTokenManager.list_active_sessions()
      assert length(sessions) >= 1
      session_ids = Enum.map(sessions, & &1.session_id)
      assert session_id in session_ids
    end

    test "session entry has required keys" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id)
      [session | _] = AuthTokenManager.list_active_sessions()
      assert Map.has_key?(session, :session_id)
      assert Map.has_key?(session, :status)
    end
  end

  describe "revoke_token/1" do
    test "returns error for unknown session" do
      result = AuthTokenManager.revoke_token("no_session_#{:rand.uniform(9999)}")
      assert result == {:error, :session_not_found}
    end

    test "returns ok after revoking valid session" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id)
      result = AuthTokenManager.revoke_token(session_id)
      assert result == :ok
    end

    test "session no longer accessible after revocation" do
      session_id = "session_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id)
      :ok = AuthTokenManager.revoke_token(session_id)
      result = AuthTokenManager.get_token_info(session_id)
      assert result == {:error, :session_not_found}
    end
  end

  describe "emergency_revoke_all/0" do
    test "returns :ok" do
      assert :ok = AuthTokenManager.emergency_revoke_all()
    end

    test "clears all sessions" do
      session_id1 = "session_a_#{System.unique_integer([:positive])}"
      session_id2 = "session_b_#{System.unique_integer([:positive])}"
      {:ok, _} = AuthTokenManager.authenticate("validapikey123", session_id1)
      {:ok, _} = AuthTokenManager.authenticate("validapikey456", session_id2)

      :ok = AuthTokenManager.emergency_revoke_all()

      sessions = AuthTokenManager.list_active_sessions()
      assert sessions == []
    end
  end
end
