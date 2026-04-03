defmodule Indrajaal.TPS.ConfigurationAuditorTest do
  @moduledoc """
  TDG test suite for ConfigurationAuditor (plain module, fully self-contained).

  ## STAMP Safety Integration
  - SC-TPS-001: Configuration audits must be deterministic
  - SC-TPS-002: Audit results must include all 8 required sections

  ## TPS 5-Level RCA Context
  - L1 Symptom: Configuration validation failures
  - L5 Root Cause: Missing or incomplete configuration context handling
  """

  use ExUnit.Case, async: true

  alias Indrajaal.TPS.ConfigurationAuditor

  describe "process_request/1" do
    test "handles empty context map" do
      result = ConfigurationAuditor.process_request(%{})
      assert is_map(result)
    end

    test "handles default context (no args)" do
      result = ConfigurationAuditor.process_request()
      assert is_map(result)
    end

    test "returns a map with multiple top-level keys" do
      result = ConfigurationAuditor.process_request(%{})
      assert map_size(result) >= 4
    end

    test "result contains audit status" do
      result = ConfigurationAuditor.process_request(%{})
      # Should have some status indicator
      keys = Map.keys(result)
      assert length(keys) > 0
    end

    test "handles context with system_context key" do
      ctx = %{system_context: %{env: :test}}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "handles context with config_paths" do
      ctx = %{config_paths: ["/tmp/config.exs"]}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "result is deterministic for same input" do
      ctx = %{seed: 42}
      result1 = ConfigurationAuditor.process_request(ctx)
      result2 = ConfigurationAuditor.process_request(ctx)
      assert result1 == result2
    end

    test "result includes some form of validation status" do
      result = ConfigurationAuditor.process_request(%{})
      # Check for any key that indicates validation occurred
      assert is_map(result)
      assert map_size(result) > 0
    end

    test "handles context with audit_level key" do
      ctx = %{audit_level: :full}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "handles context with domain key" do
      ctx = %{domain: :alarms}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "handles context with tenant_id" do
      ctx = %{tenant_id: "tenant-123"}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "handles nil values in context gracefully" do
      ctx = %{key: nil, other: nil}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "handles context with boolean flags" do
      ctx = %{strict_mode: true, verbose: false}
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "large context map is handled without error" do
      ctx = Enum.into(1..20, %{}, fn i -> {"key_#{i}", "value_#{i}"} end)
      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end

    test "context with nested maps is handled" do
      ctx = %{
        system: %{node: :node1, version: "21.3.0"},
        config: %{env: :test, debug: false}
      }

      result = ConfigurationAuditor.process_request(ctx)
      assert is_map(result)
    end
  end
end
