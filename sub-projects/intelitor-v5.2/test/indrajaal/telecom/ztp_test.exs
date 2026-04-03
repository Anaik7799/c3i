defmodule Indrajaal.Telecom.ZTPTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Telecom.ZTP

  describe "provision_device/2" do
    test "returns {:ok, :provisioned} for a valid sztp- prefixed device ID" do
      assert {:ok, :provisioned} = ZTP.provision_device("sztp-001", "base-station-5g")
    end

    test "returns {:ok, :provisioned} for a longer sztp- device ID" do
      assert {:ok, :provisioned} = ZTP.provision_device("sztp-router-abc123", "core-router")
    end

    test "returns {:error, :invalid_identity} for device ID without sztp- prefix" do
      assert {:error, :invalid_identity} = ZTP.provision_device("rogue-device", "spyware")
    end

    test "returns {:error, :invalid_identity} for empty device ID" do
      assert {:error, :invalid_identity} = ZTP.provision_device("", "any-profile")
    end

    test "returns {:error, :invalid_identity} for device ID with sztp prefix but wrong separator" do
      assert {:error, :invalid_identity} = ZTP.provision_device("sztp001", "profile")
    end

    test "returns {:error, :invalid_identity} for device ID starting with similar but wrong prefix" do
      assert {:error, :invalid_identity} = ZTP.provision_device("xztp-device", "profile")
    end

    test "provisions with any non-empty profile when device ID is valid" do
      assert {:ok, :provisioned} = ZTP.provision_device("sztp-dev-1", "5g-small-cell")
      assert {:ok, :provisioned} = ZTP.provision_device("sztp-dev-2", "4g-macro")
      assert {:ok, :provisioned} = ZTP.provision_device("sztp-dev-3", "")
    end

    test "returns a two-element tuple in all cases" do
      valid = ZTP.provision_device("sztp-x", "prof")
      invalid = ZTP.provision_device("bad-id", "prof")

      assert is_tuple(valid) and tuple_size(valid) == 2
      assert is_tuple(invalid) and tuple_size(invalid) == 2
    end

    test "invalid device ignores the profile argument" do
      assert {:error, :invalid_identity} = ZTP.provision_device("no-prefix", "legit-profile")
      assert {:error, :invalid_identity} = ZTP.provision_device("no-prefix", "other-profile")
    end
  end
end
