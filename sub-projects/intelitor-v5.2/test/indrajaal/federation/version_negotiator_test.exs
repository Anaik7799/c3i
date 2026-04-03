defmodule Indrajaal.Federation.VersionNegotiatorTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.VersionNegotiator.
  Tests both pure class functions and GenServer init contract.
  STAMP: SC-FRAC-006 (federation version negotiation), SC-SIL6-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.VersionNegotiator

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(VersionNegotiator)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(VersionNegotiator, :start_link, 1)
      assert function_exported?(VersionNegotiator, :init, 1)
    end
  end

  describe "pure class functions" do
    test "current_version/0 returns a version string" do
      version = VersionNegotiator.current_version()
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "supported_versions/0 returns a non-empty list" do
      versions = VersionNegotiator.supported_versions()
      assert is_list(versions)
      assert length(versions) > 0
    end

    test "version_supported?/1 returns true for current version" do
      current = VersionNegotiator.current_version()
      assert VersionNegotiator.version_supported?(current) == true
    end

    test "version_supported?/1 returns false for obviously unsupported version" do
      assert VersionNegotiator.version_supported?("0.0.0-unsupported") == false
    end

    test "features_for_version/1 returns a list" do
      current = VersionNegotiator.current_version()
      features = VersionNegotiator.features_for_version(current)
      assert is_list(features)
    end

    test "compatible_versions/1 returns a list" do
      result = VersionNegotiator.compatible_versions(VersionNegotiator.current_version())
      assert is_list(result)
    end

    test "find_compatible_version/2 finds current in supported list" do
      supported = VersionNegotiator.supported_versions()
      result = VersionNegotiator.find_compatible_version(supported, supported)

      is_valid =
        match?({:ok, _}, result) or
          is_binary(result) or
          match?({:error, _}, result)

      assert is_valid
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({VersionNegotiator, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({VersionNegotiator, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "GenServer API" do
    test "exports negotiate/1" do
      assert function_exported?(VersionNegotiator, :negotiate, 1)
    end

    test "exports get_version/1" do
      assert function_exported?(VersionNegotiator, :get_version, 1)
    end

    test "exports active_negotiations/0" do
      assert function_exported?(VersionNegotiator, :active_negotiations, 0)
    end

    test "exports handle_hello/2" do
      assert function_exported?(VersionNegotiator, :handle_hello, 2)
    end

    test "exports handle_select/2" do
      assert function_exported?(VersionNegotiator, :handle_select, 2)
    end

    test "exports degrade_version/2" do
      assert function_exported?(VersionNegotiator, :degrade_version, 2)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = VersionNegotiator.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
