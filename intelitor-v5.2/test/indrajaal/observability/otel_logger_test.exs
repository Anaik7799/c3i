defmodule Indrajaal.Observability.OTELLoggerTest do
  @moduledoc """
  Test suite for OTEL Logger functionality focusing on automatic trace correlation.

  This module tests:
  - Automatic trace ID injection into log metadata
  - Span ID correlation with log __events
  - Trace __context propagation across processes
  - Multi-tenant trace isolation
  - STAMP safety constraints for observability
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.OTELLogger

  describe "trace correlation" do
    test "automatically injects trace_id and span_id into log metadata" do
      # Given a trace __context is active
      trace_id = "00112233445566778899aabbccddeeff"
      span_id = "0_011_223_344_556_677"

      # When logging occurs
      result = OTELLogger.log(:info, "Test message", %{__user_id: 123})

      # Then trace __context should be included
      assert result.metadata.trace_id == trace_id
      assert result.metadata.span_id == span_id
      assert result.metadata.__user_id == 123
    end

    test "preserves existing metadata when adding trace __context" do
      # Given existing metadata
      metadata = %{
        tenant_id: "tenant_123",
        __request_id: "__req_456",
        custom_field: "value"
      }

      # When trace __context is added
      result = OTELLogger.enrich__metadata(metadata)

      # Then all fields should be preserved
      assert result.tenant_id == "tenant_123"
      assert result.__request_id == "__req_456"
      assert result.custom_field == "value"
      assert Map.has_key?(result, :trace_id)
      assert Map.has_key?(result, :span_id)
    end

    test "handles missing trace __context gracefully" do
      # Given no active trace __context
      # When logging occurs without trace
      result = OTELLogger.log(:warn, "No trace message", %{})

      # Then it should succeed without trace fields
      assert result.level == :warn
      assert result.message == "No trace message"
      refute Map.has_key?(result.metadata, :trace_id)
      refute Map.has_key?(result.metadata, :span_id)
    end
  end

  describe "cross-process propagation" do
    test "propagates trace __context to spawned processes" do
      # Given a parent process with trace __context
      parent_trace_id = "parent_trace_123"

      # When spawning a child process
      {:ok, child_pid} =
        OTELLogger.spawn_with_trace(fn ->
          OTELLogger.get_current_trace()
        end)

      # Then child should inherit trace __context
      child_trace = OTELLogger.get_process_trace(child_pid)
      assert child_trace.trace_id == parent_trace_id
      assert child_trace.parent_span_id != nil
    end

    test "creates new span for async operations" do
      # Given an async operation
      parent_span = OTELLogger.start_span("parent_operation")

      # When starting async work
      async_result =
        OTELLogger.async_with_span("async_work", fn ->
          OTELLogger.get_current_span()
        end)

      # Then it should have its own span linked to parent
      assert async_result.span_id != parent_span.span_id
      assert async_result.parent_span_id == parent_span.span_id
      assert async_result.trace_id == parent_span.trace_id
    end
  end

  describe "multi-tenant isolation" do
    test "ensures trace __contexts are isolated by tenant" do
      # Given two different tenants
      tenant1_trace =
        OTELLogger.with_tenant("tenant_1", fn ->
          OTELLogger.start_trace("operation_1")
        end)

      tenant2_trace =
        OTELLogger.with_tenant("tenant_2", fn ->
          OTELLogger.start_trace("operation_2")
        end)

      # Then traces should be completely isolated
      assert tenant1_trace.tenant_id == "tenant_1"
      assert tenant2_trace.tenant_id == "tenant_2"
      assert tenant1_trace.trace_id != tenant2_trace.trace_id
    end

    test "prevents cross-tenant trace correlation" do
      # Given a trace from tenant 1
      OTELLogger.with_tenant("tenant_1", fn ->
        OTELLogger.start_trace("tenant1_op")
      end)

      # When tenant 2 tries to correlate
      result =
        OTELLogger.with_tenant("tenant_2", fn ->
          OTELLogger.correlate_with_trace("tenant1_op")
        end)

      # Then correlation should fail
      assert {:error, :unauthorized} = result
    end
  end

  describe "STAMP safety constraints" do
    test "enforces maximum trace depth to prevent infinite recursion" do
      # Given maximum depth is reached
      OTELLogger.set_max_trace_depth(5)

      # When trying to exceed depth
      result =
        Enum.reduce(1..6, :ok, fn i, _acc ->
          OTELLogger.start_span("level_#{i}")
        end)

      # Then it should enforce safety limit
      assert {:error, :max_depth_exceeded} = result
    end

    test "limits trace metadata size to prevent memory issues" do
      # Given large metadata
      large_metadata = Map.new(1..1000, fn i -> {"key_#{i}", String.duplicate("x", 1000)} end)

      # When trying to log with oversized metadata
      result = OTELLogger.log(:info, "Large metadata", large_metadata)

      # Then it should truncate safely
      assert map_size(result.metadata) <= OTELLogger.max_metadata_fields()
      assert result.metadata._truncated == true
    end

    test "implements circuit breaker for trace export failures" do
      # Given export failures
      OTELLogger.simulate_export_failures(10)

      # When circuit breaker trips
      status = OTELLogger.get_exporter_status()

      # Then it should be in open __state
      assert status.circuit_breaker == :open
      assert status.failure_count >= 10

      # And new traces should be buffered locally
      result = OTELLogger.start_trace("buffered_op")
      assert result.buffered == true
    end
  end

  describe "performance characteristics" do
    test "adds minimal overhead to logging operations" do
      # Given baseline logging performance
      baseline_time =
        measure_logging_time(fn ->
          Logger.info("Baseline message")
        end)

      # When using OTEL logger
      otel_time =
        measure_logging_time(fn ->
          OTELLogger.log(:info, "OTEL message", %{})
        end)

      # Then overhead should be minimal
      overhead_percentage = (otel_time - baseline_time) / baseline_time * 100
      # Less than 10% overhead
      assert overhead_percentage < 10.0
    end

    test "batches trace exports efficiently" do
      # Given multiple traces
      traces =
        Enum.map(1..100, fn i ->
          OTELLogger.start_trace("batch_op_#{i}")
        end)

      # When export occurs
      export_result = OTELLogger.export_traces(traces)

      # Then it should batch efficiently
      # At most 10 batches for 100 traces
      assert export_result.batch_count <= 10
      assert export_result.success_count == 100
    end
  end

  defp measure_logging_time(fun) do
    {time, _} =
      :timer.tc(fn ->
        Enum.each(1..1000, fn _ -> fun.() end)
      end)

    # Convert to milliseconds
    time / 1000
  end
end
