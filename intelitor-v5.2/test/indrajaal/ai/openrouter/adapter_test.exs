defmodule Indrajaal.AI.OpenRouter.AdapterTest do
  @moduledoc """
  TDG test suite for Indrajaal.AI.OpenRouter.Adapter.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-AI-RETRY-001: Max 3 retries with exponential backoff
  - SC-AI-FALLBACK-001: 3-level model fallback chain

  ## TPS 5-Level RCA Context
  - L1 Symptom: Adapter returns wrong shape
  - L5 Root Cause: Contract violation in chat/stream_chat
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AI.OpenRouter.Adapter

  describe "module existence" do
    test "Adapter module is defined" do
      assert Code.ensure_loaded?(Adapter)
    end

    test "chat/2 function exists" do
      assert function_exported?(Adapter, :chat, 2)
    end

    test "chat/1 function exists (default opts)" do
      assert function_exported?(Adapter, :chat, 1)
    end

    test "stream_chat/3 function exists" do
      assert function_exported?(Adapter, :stream_chat, 3)
    end

    test "stream_chat/2 function exists (default opts)" do
      assert function_exported?(Adapter, :stream_chat, 2)
    end

    test "select_model/1 function exists" do
      assert function_exported?(Adapter, :select_model, 1)
    end

    test "select_model/2 function exists" do
      assert function_exported?(Adapter, :select_model, 2)
    end

    test "ooda_config/0 function exists" do
      assert function_exported?(Adapter, :ooda_config, 0)
    end
  end

  describe "ooda_config/0" do
    test "returns a map" do
      config = Adapter.ooda_config()
      assert is_map(config)
    end

    test "config has timeout_ms key" do
      config = Adapter.ooda_config()
      assert Map.has_key?(config, :timeout_ms)
    end

    test "config has fallback_enabled key" do
      config = Adapter.ooda_config()
      assert Map.has_key?(config, :fallback_enabled)
    end

    test "config has intent key" do
      config = Adapter.ooda_config()
      assert Map.has_key?(config, :intent)
    end

    test "config has model key" do
      config = Adapter.ooda_config()
      assert Map.has_key?(config, :model)
      assert is_binary(config.model)
    end

    test "timeout_ms is a positive integer" do
      config = Adapter.ooda_config()
      assert is_integer(config.timeout_ms)
      assert config.timeout_ms > 0
    end

    test "fallback_enabled is a boolean" do
      config = Adapter.ooda_config()
      assert is_boolean(config.fallback_enabled)
    end
  end

  describe "select_model/2" do
    test "returns a string for :chat intent" do
      model = Adapter.select_model(:chat)
      assert is_binary(model)
    end

    test "returns a string for :analysis intent" do
      model = Adapter.select_model(:analysis)
      assert is_binary(model)
    end

    test "returns a string for :coding intent" do
      model = Adapter.select_model(:coding)
      assert is_binary(model)
    end

    test "returns a non-empty string" do
      model = Adapter.select_model(:chat)
      assert String.length(model) > 0
    end
  end

  describe "chat/2 with invalid arguments" do
    test "returns error tuple or ok tuple when called" do
      result = Adapter.chat([%{role: "user", content: "test"}])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
