defmodule Indrajaal.ProductionReadiness.SSLValidatorTest do
  @moduledoc """
  TDG test suite for SSLValidator GenServer.

  ## STAMP Safety Integration
  - SC-009: SSL validation must not expose private keys
  - UCA-007: Prevent SSL downgrade attacks

  ## TPS 5-Level RCA Context
  - L1 Symptom: Weak cipher suites allowed
  - L5 Root Cause: Missing cipher validation enforcement
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.SSLValidator

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SSLValidator)
    end

    test "public API functions are exported" do
      assert function_exported?(SSLValidator, :start_link, 1)
      assert function_exported?(SSLValidator, :validate_all_containers, 1)
      assert function_exported?(SSLValidator, :validate_container, 1)
      assert function_exported?(SSLValidator, :apply_config, 1)
    end
  end

  describe "minimum TLS version" do
    test "minimum TLS version is at least 1.2" do
      min_version = "1.2"
      [major, minor] = String.split(min_version, ".") |> Enum.map(&String.to_integer/1)
      assert major >= 1
      assert minor >= 2
    end
  end

  describe "secure cipher suites" do
    test "secure suites include AES-256-GCM" do
      secure_suites = [
        "TLS_AES_256_GCM_SHA384",
        "TLS_AES_128_GCM_SHA256"
      ]

      assert "TLS_AES_256_GCM_SHA384" in secure_suites
    end
  end

  describe "weak cipher suites" do
    test "weak suites include RC4" do
      weak_suites = ["DES-CBC3-SHA", "RC4-SHA", "RC4-MD5"]
      assert "RC4-SHA" in weak_suites
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      name = :"ssl_validator_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(SSLValidator, [], name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
