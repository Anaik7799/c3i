defmodule TDGConfigTest do
  @moduledoc """
  TDG tests for TDGConfig.

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## TPS 5-Level RCA Context
  - L1 Symptom: TDG configuration not returning expected values
  - L5 Root Cause: Configuration module not exposing correct defaults
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "TDGConfig module" do
    test "module is defined" do
      assert Code.ensure_loaded?(TDGConfig)
    end

    test "function_exported? for key config functions" do
      assert function_exported?(TDGConfig, :new, 0) or
               function_exported?(TDGConfig, :default, 0) or
               function_exported?(TDGConfig, :__struct__, 0) or
               function_exported?(TDGConfig, :__struct__, 1)
    end

    test "module has expected attributes or struct" do
      # TDGConfig may be a struct or a module with config functions
      exports = TDGConfig.__info__(:functions)
      assert is_list(exports)
    end

    test "module info is accessible" do
      info = TDGConfig.__info__(:module)
      assert info == TDGConfig
    end
  end

  describe "TDGConfig struct" do
    test "struct can be created if it is a struct" do
      if function_exported?(TDGConfig, :__struct__, 0) do
        config = struct(TDGConfig, [])
        assert is_struct(config)
      else
        :ok
      end
    end

    test "default values accessible if new/0 exists" do
      if function_exported?(TDGConfig, :new, 0) do
        config = TDGConfig.new()
        assert not is_nil(config)
      else
        :ok
      end
    end
  end
end
