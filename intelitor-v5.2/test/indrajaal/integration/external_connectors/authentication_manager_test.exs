defmodule Indrajaal.Integration.ExternalConnectors.AuthenticationManagerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Integration.ExternalConnectors.AuthenticationManager.

  ## STAMP Safety Integration
  - SC-SEC-047: Credentials stored (KMS integration placeholder)
  - SC-PRF-055: No blocking operations in the hot path

  ## TPS 5-Level RCA Context
  - L1 Symptom: Token retrieval fails unexpectedly
  - L5 Root Cause: ETS table not initialized or token expiry logic error
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.ExternalConnectors.AuthenticationManager

  setup do
    AuthenticationManager.ensure_table()
    :ok
  end

  describe "ensure_table/0" do
    test "returns :ok on first call" do
      assert :ok = AuthenticationManager.ensure_table()
    end

    test "is idempotent — safe to call multiple times" do
      assert :ok = AuthenticationManager.ensure_table()
      assert :ok = AuthenticationManager.ensure_table()
    end
  end

  describe "refresh_token/1" do
    test "generates a new token string" do
      connector_id = "auth_refresh_#{:erlang.unique_integer([:positive])}"
      assert {:ok, token} = AuthenticationManager.refresh_token(connector_id)
      assert is_binary(token)
      assert String.length(token) > 10
    end

    test "token contains connector_id prefix" do
      connector_id = "my_connector_#{:erlang.unique_integer([:positive])}"
      {:ok, token} = AuthenticationManager.refresh_token(connector_id)
      assert String.starts_with?(token, "tok_#{connector_id}_")
    end

    test "generates different token on each refresh" do
      connector_id = "multi_refresh_#{:erlang.unique_integer([:positive])}"
      {:ok, token1} = AuthenticationManager.refresh_token(connector_id)
      {:ok, token2} = AuthenticationManager.refresh_token(connector_id)
      assert token1 != token2
    end
  end

  describe "get_valid_token/1" do
    test "returns not_found when no token exists" do
      connector_id = "no_token_#{:erlang.unique_integer([:positive])}"
      assert {:error, :not_found} = AuthenticationManager.get_valid_token(connector_id)
    end

    test "returns valid token after refresh" do
      connector_id = "valid_token_#{:erlang.unique_integer([:positive])}"
      {:ok, refreshed} = AuthenticationManager.refresh_token(connector_id)
      assert {:ok, token} = AuthenticationManager.get_valid_token(connector_id)
      assert token == refreshed
    end
  end

  describe "revoke_token/1" do
    test "returns :ok even when no token exists (idempotent)" do
      connector_id = "revoke_nonexistent_#{:erlang.unique_integer([:positive])}"
      assert :ok = AuthenticationManager.revoke_token(connector_id)
    end

    test "revoked token cannot be retrieved" do
      connector_id = "revoke_existing_#{:erlang.unique_integer([:positive])}"
      {:ok, _token} = AuthenticationManager.refresh_token(connector_id)
      # Verify token is there
      assert {:ok, _} = AuthenticationManager.get_valid_token(connector_id)

      # Revoke
      :ok = AuthenticationManager.revoke_token(connector_id)

      # Should now be not_found
      assert {:error, _} = AuthenticationManager.get_valid_token(connector_id)
    end
  end

  describe "store_credentials/2" do
    test "stores credentials and returns :ok" do
      connector_id = "store_creds_#{:erlang.unique_integer([:positive])}"
      credentials = %{client_id: "abc123", client_secret: "secret"}
      assert :ok = AuthenticationManager.store_credentials(connector_id, credentials)
    end

    test "stores different credential shapes" do
      connector_id = "varied_creds_#{:erlang.unique_integer([:positive])}"

      assert :ok =
               AuthenticationManager.store_credentials(connector_id, %{
                 api_key: "key123",
                 api_secret: "secret456",
                 endpoint: "https://api.example.com"
               })
    end
  end

  describe "validate_credentials/1" do
    test "returns credentials_not_found when none stored" do
      connector_id = "no_creds_#{:erlang.unique_integer([:positive])}"

      assert {:error, :credentials_not_found} =
               AuthenticationManager.validate_credentials(connector_id)
    end

    test "returns valid after storing credentials" do
      connector_id = "valid_creds_#{:erlang.unique_integer([:positive])}"

      :ok =
        AuthenticationManager.store_credentials(connector_id, %{
          client_id: "x",
          client_secret: "y"
        })

      assert {:ok, :valid} = AuthenticationManager.validate_credentials(connector_id)
    end
  end

  describe "generic CRUD API" do
    test "list_all/0 returns ok with list of token entries" do
      assert {:ok, list} = AuthenticationManager.list_all()
      assert is_list(list)
    end

    test "get_by_id/1 returns error when no token for id" do
      connector_id = "get_by_id_no_token_#{:erlang.unique_integer([:positive])}"
      assert {:error, :not_found} = AuthenticationManager.get_by_id(connector_id)
    end

    test "get_by_id/1 returns ok with active token info when token exists" do
      connector_id = "get_by_id_with_token_#{:erlang.unique_integer([:positive])}"
      {:ok, _} = AuthenticationManager.refresh_token(connector_id)
      assert {:ok, info} = AuthenticationManager.get_by_id(connector_id)
      assert info.id == connector_id
      assert info.status == :active
    end

    test "create/1 with connector_id stores credentials and returns ok" do
      connector_id = "create_auth_#{:erlang.unique_integer([:positive])}"
      params = %{connector_id: connector_id, client_id: "abc", client_secret: "def"}
      assert {:ok, created} = AuthenticationManager.create(params)
      assert created.id == connector_id
    end

    test "create/1 without connector_id returns error" do
      assert {:error, {:missing_connector_id, _}} = AuthenticationManager.create(%{name: "test"})
    end

    test "update/2 stores updated credentials" do
      connector_id = "update_auth_#{:erlang.unique_integer([:positive])}"
      assert {:ok, updated} = AuthenticationManager.update(connector_id, %{client_id: "new_id"})
      assert updated.id == connector_id
    end

    test "delete/1 removes credentials and token, returns deleted marker" do
      connector_id = "delete_auth_#{:erlang.unique_integer([:positive])}"
      :ok = AuthenticationManager.store_credentials(connector_id, %{client_id: "x"})
      {:ok, _} = AuthenticationManager.refresh_token(connector_id)

      assert {:ok, %{deleted: true}} = AuthenticationManager.delete(connector_id)

      # After delete, token should be gone
      assert {:error, _} = AuthenticationManager.get_valid_token(connector_id)
    end
  end
end
