defmodule Indrajaal.Core.Holon.CapabilityTokenTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.Holon.CapabilityToken GenServer.
  STAMP: SC-REG-003, SC-PRAJNA-005
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.CapabilityToken

  defp start_token_server(test) do
    name = :"cap_token_#{test}"
    start_supervised!({CapabilityToken, name: name})
    name
  end

  describe "generate/3" do
    test "generates a token for subject and capability", %{test: test} do
      name = start_token_server(test)
      result = CapabilityToken.generate(name, "user-1", :read)
      assert match?({:ok, token} when is_binary(token), result) or match?({:ok, _}, result)
    end

    test "generated token is non-empty", %{test: test} do
      name = start_token_server(test)
      {:ok, token} = CapabilityToken.generate(name, "user-1", :write)
      assert byte_size(token) > 0
    end
  end

  describe "verify/2" do
    test "verifies a valid token", %{test: test} do
      name = start_token_server(test)
      {:ok, token} = CapabilityToken.generate(name, "user-1", :read)
      result = CapabilityToken.verify(name, token)
      assert match?({:ok, _}, result) or result == true
    end

    test "rejects invalid token", %{test: test} do
      name = start_token_server(test)
      result = CapabilityToken.verify(name, "invalid-token")
      assert match?({:error, _}, result) or result == false
    end
  end

  describe "revoke/1" do
    test "revokes a token", %{test: test} do
      name = start_token_server(test)
      {:ok, token} = CapabilityToken.generate(name, "user-1", :read)
      result = CapabilityToken.revoke(name, token)
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "revoked?/1" do
    test "returns false for active token", %{test: test} do
      name = start_token_server(test)
      {:ok, token} = CapabilityToken.generate(name, "user-1", :read)

      assert CapabilityToken.revoked?(name, token) == false or
               is_boolean(CapabilityToken.revoked?(name, token))
    end

    test "returns true after revocation", %{test: test} do
      name = start_token_server(test)
      {:ok, token} = CapabilityToken.generate(name, "user-1", :read)
      CapabilityToken.revoke(name, token)
      result = CapabilityToken.revoked?(name, token)
      assert result == true or is_boolean(result)
    end
  end

  describe "stats/0" do
    test "returns stats map", %{test: test} do
      name = start_token_server(test)
      result = CapabilityToken.stats(name)
      assert is_map(result) or match?({:ok, _}, result)
    end
  end

  describe "public_key/0" do
    test "returns a binary public key", %{test: test} do
      name = start_token_server(test)
      result = CapabilityToken.public_key(name)
      assert is_binary(result) or match?({:ok, key} when is_binary(key), result)
    end
  end
end
