defmodule Indrajaal.Observability.DatadogMetadataTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.DatadogMetadata.

  ## STAMP Safety Integration
  - SC-OBS-071: All OTEL modules must function correctly

  ## TPS 5-Level RCA Context
  - L1 Symptom: Missing Datadog tags in telemetry events
  - L5 Root Cause: Breaks distributed tracing across observability stack
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.DatadogMetadata

  describe "tags/1" do
    test "returns a map" do
      result = DatadogMetadata.tags(%{})
      assert is_map(result)
    end

    test "includes env tag" do
      result = DatadogMetadata.tags(%{})
      assert Map.has_key?(result, "env")
    end

    test "includes service tag" do
      result = DatadogMetadata.tags(%{})
      assert Map.has_key?(result, "service")
      assert result["service"] == "indrajaal"
    end

    test "includes version tag" do
      result = DatadogMetadata.tags(%{})
      assert Map.has_key?(result, "version")
    end

    test "adds saga.name for saga metadata" do
      result = DatadogMetadata.tags(%{saga_name: "alarm-processing"})
      assert Map.has_key?(result, "saga.name")
      assert result["saga.name"] == "alarm-processing"
    end

    test "adds graph.nodes for nodes metadata" do
      result = DatadogMetadata.tags(%{nodes: 5})
      assert Map.has_key?(result, "graph.nodes")
      assert result["graph.nodes"] == 5
    end

    test "empty metadata returns base tags only" do
      result = DatadogMetadata.tags(%{})
      assert map_size(result) == 3
    end

    test "unknown metadata keys don't break tag generation" do
      result = DatadogMetadata.tags(%{unknown_key: "value"})
      assert is_map(result)
      assert Map.has_key?(result, "service")
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.DatadogMetadata)
    end

    test "tags/1 exported" do
      assert function_exported?(Indrajaal.Observability.DatadogMetadata, :tags, 1)
    end
  end
end
