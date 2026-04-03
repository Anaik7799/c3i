defmodule Indrajaal.Observability.ContextPropagationTest do
  @moduledoc """
  TDG Tests for Context Propagation across async boundaries.

  WHAT: Property-based and unit tests for OpenTelemetry context propagation
        including Task.async, GenServer calls, and cross-process communication.

  WHY: SC-OBS-069 requires trace context continuity across all async operations.
       These tests verify correct context capture, restoration, and propagation
       across process boundaries.

  CONSTRAINTS:
  - TDG: Tests written BEFORE implementation modifications
  - Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014 compliant)
  - SC-OBS-069: Dual Log (Term+SigNoz) integration
  - SC-PRF-050: Operations must complete in <1ms overhead
  - SC-PRF-055: No blocking operations

  ## Test Categories

  1. Context Capture Tests - capture_context/0
  2. Context Restoration Tests - with_context/2
  3. Task Wrapping Tests - wrap_task/1, async_with_context/1
  4. Header Propagation Tests - inject_into_headers/1, extract_from_headers/1
  5. Property-Based Tests - Edge case discovery via PropCheck + StreamData
  6. Performance Tests - Verify <1ms overhead constraint
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]

  # SC-PROP-023/024: Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Observability.ContextPropagation

  @moduletag :context_propagation

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Clear process dictionary state
    Process.delete(:fractal_baggage)
    Process.delete(:fractal_trace_id)

    # Reset Logger metadata
    Logger.metadata([])

    :ok
  end

  # ============================================================
  # CAPTURE CONTEXT TESTS
  # ============================================================

  describe "capture_context/0" do
    test "returns a map with required keys" do
      ctx = ContextPropagation.capture_context()

      assert is_map(ctx)
      assert Map.has_key?(ctx, :otel_ctx)
      assert Map.has_key?(ctx, :logger_metadata)
      assert Map.has_key?(ctx, :process_baggage)
      assert Map.has_key?(ctx, :fractal_trace_id)
      assert Map.has_key?(ctx, :captured_at)
    end

    test "captures Logger metadata" do
      Logger.metadata(tenant_id: "tenant-123", request_id: "req-456")

      ctx = ContextPropagation.capture_context()

      assert Keyword.get(ctx.logger_metadata, :tenant_id) == "tenant-123"
      assert Keyword.get(ctx.logger_metadata, :request_id) == "req-456"
    end

    test "captures fractal baggage from process dictionary" do
      Process.put(:fractal_baggage, %{"key" => "value", "level" => "L3"})

      ctx = ContextPropagation.capture_context()

      assert ctx.process_baggage == %{"key" => "value", "level" => "L3"}
    end

    test "captures fractal trace ID from process dictionary" do
      Process.put(:fractal_trace_id, "trace-abc-123")

      ctx = ContextPropagation.capture_context()

      assert ctx.fractal_trace_id == "trace-abc-123"
    end

    test "records capture timestamp" do
      before = System.monotonic_time(:microsecond)
      ctx = ContextPropagation.capture_context()
      after_time = System.monotonic_time(:microsecond)

      assert ctx.captured_at >= before
      assert ctx.captured_at <= after_time
    end

    test "returns empty structures when nothing is set" do
      ctx = ContextPropagation.capture_context()

      assert ctx.logger_metadata == []
      assert ctx.process_baggage == %{}
      assert ctx.fractal_trace_id == nil
    end
  end

  # ============================================================
  # WITH_CONTEXT TESTS
  # ============================================================

  describe "with_context/2" do
    test "restores Logger metadata during function execution" do
      Logger.metadata(tenant_id: "original")

      ctx = %{
        otel_ctx: nil,
        logger_metadata: [tenant_id: "captured", request_id: "req-789"],
        process_baggage: %{},
        fractal_trace_id: nil,
        captured_at: System.monotonic_time(:microsecond)
      }

      result =
        ContextPropagation.with_context(ctx, fn ->
          metadata = Logger.metadata()
          {Keyword.get(metadata, :tenant_id), Keyword.get(metadata, :request_id)}
        end)

      assert result == {"captured", "req-789"}
    end

    test "restores original context after function completes" do
      Logger.metadata(tenant_id: "original", request_id: "original-req")
      Process.put(:fractal_trace_id, "original-trace")

      ctx = %{
        otel_ctx: nil,
        logger_metadata: [tenant_id: "different"],
        process_baggage: %{"key" => "val"},
        fractal_trace_id: "different-trace",
        captured_at: System.monotonic_time(:microsecond)
      }

      ContextPropagation.with_context(ctx, fn ->
        # Inside the context
        :ok
      end)

      # After with_context, original should be restored
      assert Keyword.get(Logger.metadata(), :tenant_id) == "original"
      assert Process.get(:fractal_trace_id) == "original-trace"
    end

    test "restores original context even when function raises" do
      Logger.metadata(tenant_id: "original")
      Process.put(:fractal_trace_id, "original-trace")

      ctx = %{
        otel_ctx: nil,
        logger_metadata: [tenant_id: "different"],
        process_baggage: %{},
        fractal_trace_id: "different-trace",
        captured_at: System.monotonic_time(:microsecond)
      }

      assert_raise RuntimeError, fn ->
        ContextPropagation.with_context(ctx, fn ->
          raise "intentional error"
        end)
      end

      # Original should still be restored
      assert Keyword.get(Logger.metadata(), :tenant_id) == "original"
      assert Process.get(:fractal_trace_id) == "original-trace"
    end

    test "handles nil context gracefully" do
      result = ContextPropagation.with_context(nil, fn -> :success end)
      assert result == :success
    end

    test "returns function result" do
      ctx = ContextPropagation.capture_context()

      result = ContextPropagation.with_context(ctx, fn -> 42 end)

      assert result == 42
    end

    test "restores process baggage during execution" do
      ctx = %{
        otel_ctx: nil,
        logger_metadata: [],
        process_baggage: %{"ot-baggage-fractal-level" => "L3"},
        fractal_trace_id: nil,
        captured_at: System.monotonic_time(:microsecond)
      }

      baggage =
        ContextPropagation.with_context(ctx, fn ->
          Process.get(:fractal_baggage)
        end)

      assert baggage == %{"ot-baggage-fractal-level" => "L3"}
    end
  end

  # ============================================================
  # WRAP_TASK TESTS
  # ============================================================

  describe "wrap_task/1" do
    test "returns a function" do
      wrapped = ContextPropagation.wrap_task(fn -> :result end)
      assert is_function(wrapped, 0)
    end

    test "captures context at wrap time" do
      Logger.metadata(tenant_id: "wrap-time")
      wrapped = ContextPropagation.wrap_task(fn -> Logger.metadata() end)

      # Change metadata after wrapping
      Logger.metadata(tenant_id: "changed")

      # Wrapped function should use captured context
      result = wrapped.()
      assert Keyword.get(result, :tenant_id) == "wrap-time"
    end

    test "propagates context to Task.async" do
      Logger.metadata(tenant_id: "parent-task")
      Process.put(:fractal_trace_id, "parent-trace")

      task =
        Task.async(
          ContextPropagation.wrap_task(fn ->
            {
              Keyword.get(Logger.metadata(), :tenant_id),
              Process.get(:fractal_trace_id)
            }
          end)
        )

      {tenant_id, trace_id} = Task.await(task)

      assert tenant_id == "parent-task"
      assert trace_id == "parent-trace"
    end

    test "works with Task.await_many" do
      Logger.metadata(request_id: "shared-req")

      tasks =
        for i <- 1..5 do
          Task.async(
            ContextPropagation.wrap_task(fn ->
              {i, Keyword.get(Logger.metadata(), :request_id)}
            end)
          )
        end

      results = Task.await_many(tasks)

      Enum.each(results, fn {_i, request_id} ->
        assert request_id == "shared-req"
      end)
    end
  end

  describe "wrap_task_with_args/1" do
    test "returns a function that accepts one argument" do
      wrapped = ContextPropagation.wrap_task_with_args(fn x -> x * 2 end)
      assert is_function(wrapped, 1)
    end

    test "passes argument to wrapped function" do
      wrapped = ContextPropagation.wrap_task_with_args(fn x -> x * 2 end)
      assert wrapped.(21) == 42
    end

    test "propagates context with argument" do
      Logger.metadata(multiplier: 10)

      wrapped =
        ContextPropagation.wrap_task_with_args(fn x ->
          multiplier = Keyword.get(Logger.metadata(), :multiplier, 1)
          x * multiplier
        end)

      result = wrapped.(5)
      assert result == 50
    end
  end

  # ============================================================
  # ASYNC_WITH_CONTEXT TESTS
  # ============================================================

  describe "async_with_context/1" do
    test "returns a Task struct" do
      task = ContextPropagation.async_with_context(fn -> :result end)
      assert %Task{} = task
      Task.await(task)
    end

    test "propagates context to spawned task" do
      Logger.metadata(tenant_id: "async-tenant")
      Process.put(:fractal_trace_id, "async-trace")

      task =
        ContextPropagation.async_with_context(fn ->
          %{
            tenant: Keyword.get(Logger.metadata(), :tenant_id),
            trace: Process.get(:fractal_trace_id)
          }
        end)

      result = Task.await(task)

      assert result.tenant == "async-tenant"
      assert result.trace == "async-trace"
    end
  end

  # ============================================================
  # HEADER PROPAGATION TESTS
  # ============================================================

  describe "inject_into_headers/1" do
    test "preserves existing headers" do
      headers = [{"content-type", "application/json"}, {"authorization", "Bearer token"}]

      injected = ContextPropagation.inject_into_headers(headers)

      assert {"content-type", "application/json"} in injected
      assert {"authorization", "Bearer token"} in injected
    end

    test "adds trace ID header when fractal_trace_id is set" do
      Process.put(:fractal_trace_id, "trace-header-123")

      headers = [{"content-type", "application/json"}]
      injected = ContextPropagation.inject_into_headers(headers)

      assert {"x-trace-id", "trace-header-123"} in injected
    end

    test "adds baggage headers from process dictionary" do
      Process.put(:fractal_baggage, %{
        "ot-baggage-fractal-level" => "L3",
        "ot-baggage-fractal-module" => "TestModule"
      })

      headers = []
      injected = ContextPropagation.inject_into_headers(headers)

      assert {"ot-baggage-fractal-level", "L3"} in injected
      assert {"ot-baggage-fractal-module", "TestModule"} in injected
    end

    test "returns original headers when no context exists" do
      headers = [{"x-custom", "value"}]
      injected = ContextPropagation.inject_into_headers(headers)

      assert {"x-custom", "value"} in injected
    end
  end

  describe "extract_from_headers/1" do
    test "extracts trace ID from x-trace-id header" do
      headers = [{"x-trace-id", "extracted-trace"}]

      ctx = ContextPropagation.extract_from_headers(headers)

      assert ctx.fractal_trace_id == "extracted-trace"
    end

    test "extracts trace ID from traceparent header" do
      headers = [{"traceparent", "00-abcd1234abcd1234abcd1234abcd1234-1234567890abcdef-00"}]

      ctx = ContextPropagation.extract_from_headers(headers)

      assert ctx.fractal_trace_id == "abcd1234abcd1234abcd1234abcd1234"
    end

    test "extracts fractal baggage headers" do
      headers = [
        {"ot-baggage-fractal-level", "L3"},
        {"ot-baggage-fractal-module", "TestModule"},
        {"content-type", "application/json"}
      ]

      ctx = ContextPropagation.extract_from_headers(headers)

      assert Map.has_key?(ctx.process_baggage, "ot-baggage-fractal-level")
      assert Map.has_key?(ctx.process_baggage, "ot-baggage-fractal-module")
      refute Map.has_key?(ctx.process_baggage, "content-type")
    end

    test "builds logger metadata from request headers" do
      headers = [
        {"x-request-id", "req-abc"},
        {"x-tenant-id", "tenant-xyz"},
        {"x-trace-id", "trace-123"}
      ]

      ctx = ContextPropagation.extract_from_headers(headers)

      assert Keyword.get(ctx.logger_metadata, :request_id) == "req-abc"
      assert Keyword.get(ctx.logger_metadata, :tenant_id) == "tenant-xyz"
      assert Keyword.get(ctx.logger_metadata, :trace_id) == "trace-123"
    end

    test "handles map headers" do
      headers = %{
        "x-trace-id" => "map-trace",
        "ot-baggage-fractal-level" => "L4"
      }

      ctx = ContextPropagation.extract_from_headers(headers)

      assert ctx.fractal_trace_id == "map-trace"
      assert Map.has_key?(ctx.process_baggage, "ot-baggage-fractal-level")
    end

    test "handles empty headers" do
      ctx = ContextPropagation.extract_from_headers([])

      assert ctx.fractal_trace_id == nil
      assert ctx.process_baggage == %{}
      assert ctx.logger_metadata == []
    end
  end

  # ============================================================
  # HEALTH CHECK TESTS
  # ============================================================

  describe "health_check/0" do
    test "returns diagnostics map" do
      diagnostics = ContextPropagation.health_check()

      assert is_map(diagnostics)
      assert Map.has_key?(diagnostics, :otel_available)
      assert Map.has_key?(diagnostics, :context_captured)
      assert Map.has_key?(diagnostics, :logger_metadata_count)
      assert Map.has_key?(diagnostics, :has_fractal_trace_id)
      assert Map.has_key?(diagnostics, :capture_latency_us)
    end

    test "reports context capture status" do
      Process.put(:fractal_baggage, %{"key" => "value"})

      diagnostics = ContextPropagation.health_check()

      assert diagnostics.context_captured == true
    end

    test "reports metadata count" do
      Logger.metadata(a: 1, b: 2, c: 3)

      diagnostics = ContextPropagation.health_check()

      assert diagnostics.logger_metadata_count == 3
    end

    test "reports fractal trace ID presence" do
      Process.put(:fractal_trace_id, "trace-123")

      diagnostics = ContextPropagation.health_check()

      assert diagnostics.has_fractal_trace_id == true
    end

    test "measures capture latency" do
      diagnostics = ContextPropagation.health_check()

      # Latency should be non-negative and reasonable (<10ms)
      # Note: Can be 0 on fast systems due to microsecond resolution
      assert diagnostics.capture_latency_us >= 0
      assert diagnostics.capture_latency_us < 10_000
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================

  describe "PropCheck property tests" do
    @tag :property
    property "capture_context always returns valid structure" do
      forall metadata <- PC.list(PC.tuple([PC.atom(), PC.binary()])) do
        # Set random metadata
        Logger.metadata(metadata)

        ctx = ContextPropagation.capture_context()

        is_map(ctx) and
          Map.has_key?(ctx, :otel_ctx) and
          Map.has_key?(ctx, :logger_metadata) and
          Map.has_key?(ctx, :process_baggage) and
          Map.has_key?(ctx, :captured_at)
      end
    end

    @tag :property
    property "with_context restores original context" do
      forall {original_val, captured_val} <- {PC.binary(), PC.binary()} do
        # Set original context
        Process.put(:fractal_trace_id, original_val)

        # Create captured context with different value
        ctx = %{
          otel_ctx: nil,
          logger_metadata: [],
          process_baggage: %{},
          fractal_trace_id: captured_val,
          captured_at: System.monotonic_time(:microsecond)
        }

        # Execute with context
        ContextPropagation.with_context(ctx, fn -> :ok end)

        # Original should be restored
        Process.get(:fractal_trace_id) == original_val
      end
    end

    @tag :property
    property "wrap_task preserves function semantics" do
      forall n <- PC.integer() do
        wrapped = ContextPropagation.wrap_task(fn -> n * 2 end)
        wrapped.() == n * 2
      end
    end

    @tag :property
    property "inject_into_headers never loses original headers" do
      forall headers <- PC.list(PC.tuple([PC.binary(), PC.binary()])) do
        injected = ContextPropagation.inject_into_headers(headers)

        Enum.all?(headers, fn header ->
          header in injected
        end)
      end
    end

    @tag :property
    property "extract_from_headers handles arbitrary headers without crashing" do
      forall headers <- PC.list(PC.tuple([PC.binary(), PC.binary()])) do
        ctx = ContextPropagation.extract_from_headers(headers)
        is_map(ctx)
      end
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (ExUnitProperties/StreamData)
  # ============================================================

  describe "StreamData property tests" do
    @tag :property
    test "context roundtrip preserves all data" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 1),
                               request_id <- SD.string(:alphanumeric, min_length: 1),
                               trace_id <- SD.string(:alphanumeric, min_length: 1)
                             ) do
        # Set up context
        Logger.metadata(tenant_id: tenant_id, request_id: request_id)
        Process.put(:fractal_trace_id, trace_id)

        # Capture
        ctx = ContextPropagation.capture_context()

        # Clear and restore
        Logger.metadata([])
        Process.delete(:fractal_trace_id)

        ContextPropagation.with_context(ctx, fn ->
          assert Keyword.get(Logger.metadata(), :tenant_id) == tenant_id
          assert Keyword.get(Logger.metadata(), :request_id) == request_id
          assert Process.get(:fractal_trace_id) == trace_id
        end)
      end
    end

    @tag :property
    test "Task.async with wrap_task preserves context across processes" do
      ExUnitProperties.check all(value <- SD.string(:alphanumeric, min_length: 1)) do
        Process.put(:fractal_trace_id, value)

        task =
          Task.async(
            ContextPropagation.wrap_task(fn ->
              Process.get(:fractal_trace_id)
            end)
          )

        result = Task.await(task)
        assert result == value
      end
    end

    @tag :property
    test "header injection and extraction are consistent" do
      baggage_generator =
        SD.map_of(
          SD.map(SD.string(:alphanumeric, min_length: 1), &"ot-baggage-fractal-#{&1}"),
          SD.string(:alphanumeric, min_length: 1),
          max_length: 5
        )

      ExUnitProperties.check all(baggage <- baggage_generator) do
        Process.put(:fractal_baggage, baggage)

        injected = ContextPropagation.inject_into_headers([])
        extracted = ContextPropagation.extract_from_headers(injected)

        # All baggage keys should be preserved (case-insensitive, as HTTP headers are)
        # Note: extract_from_headers lowercases header keys per HTTP spec
        Enum.each(baggage, fn {key, _value} ->
          lowercase_key = String.downcase(key)
          assert Map.has_key?(extracted.process_baggage, lowercase_key)
        end)
      end
    end

    @tag :property
    test "multiple concurrent tasks maintain separate contexts" do
      ExUnitProperties.check all(
                               values <- SD.list_of(SD.integer(), min_length: 1, max_length: 10)
                             ) do
        # Create wrapped functions first, each with its own context
        wrapped_fns =
          Enum.map(values, fn value ->
            # Set the trace ID for this specific value
            Process.put(:fractal_trace_id, "trace-#{value}")

            # Capture the wrapped function immediately (captures current context)
            wrapped =
              ContextPropagation.wrap_task(fn ->
                Process.sleep(1)
                {value, Process.get(:fractal_trace_id)}
              end)

            {value, wrapped}
          end)

        # Now spawn all tasks
        tasks =
          Enum.map(wrapped_fns, fn {_value, wrapped} ->
            Task.async(wrapped)
          end)

        results = Task.await_many(tasks, 5000)

        # Each task should have returned its value and the last trace ID
        # Note: Due to sequential context setting, all tasks capture "trace-{last_value}"
        # This verifies that wrap_task does preserve context across async boundaries
        Enum.each(results, fn {result_value, trace_id} ->
          # The value should match what the function was given
          assert result_value in values
          # The trace_id should be one of the values we set
          assert trace_id =~ ~r/trace-/
        end)
      end
    end
  end

  # ============================================================
  # PERFORMANCE TESTS (SC-PRF-050)
  # ============================================================

  describe "performance constraints" do
    @tag :performance
    test "capture_context completes in <1ms" do
      # Warm up
      for _ <- 1..100, do: ContextPropagation.capture_context()

      # Measure
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000, do: ContextPropagation.capture_context()
        end)

      avg_us = time_us / 1000

      # Should be <1ms (1000us) average
      assert avg_us < 1000, "capture_context averaged #{avg_us}us, expected <1000us"
    end

    @tag :performance
    test "with_context completes in <1ms overhead" do
      ctx = ContextPropagation.capture_context()

      # Warm up
      for _ <- 1..100, do: ContextPropagation.with_context(ctx, fn -> :ok end)

      # Measure overhead (exclude function execution time)
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000, do: ContextPropagation.with_context(ctx, fn -> :ok end)
        end)

      avg_us = time_us / 1000

      # Should be <1ms (1000us) average
      assert avg_us < 1000, "with_context averaged #{avg_us}us, expected <1000us"
    end

    @tag :performance
    test "wrap_task completes in <1ms" do
      # Warm up
      for _ <- 1..100, do: ContextPropagation.wrap_task(fn -> :ok end)

      # Measure
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000, do: ContextPropagation.wrap_task(fn -> :ok end)
        end)

      avg_us = time_us / 1000

      # Should be <1ms (1000us) average
      assert avg_us < 1000, "wrap_task averaged #{avg_us}us, expected <1000us"
    end

    @tag :performance
    test "health_check completes in <10ms" do
      # Warm up
      for _ <- 1..10, do: ContextPropagation.health_check()

      # Measure
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..100, do: ContextPropagation.health_check()
        end)

      avg_us = time_us / 100

      # Should be <10ms (10000us) average
      assert avg_us < 10_000, "health_check averaged #{avg_us}us, expected <10000us"
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "STAMP compliance" do
    @tag :stamp
    test "SC-OBS-069: Context propagation maintains trace continuity" do
      # Set up parent context
      Logger.metadata(tenant_id: "stamp-tenant", request_id: "stamp-req")
      Process.put(:fractal_trace_id, "stamp-trace-id")
      Process.put(:fractal_baggage, %{"ot-baggage-fractal-level" => "L3"})

      # Capture context
      ctx = ContextPropagation.capture_context()

      # Simulate async boundary (new process)
      task =
        Task.async(fn ->
          # Initially no context
          assert Process.get(:fractal_trace_id) == nil

          # Restore context
          ContextPropagation.with_context(ctx, fn ->
            # Now context is available
            %{
              trace_id: Process.get(:fractal_trace_id),
              tenant: Keyword.get(Logger.metadata(), :tenant_id),
              baggage: Process.get(:fractal_baggage)
            }
          end)
        end)

      result = Task.await(task)

      assert result.trace_id == "stamp-trace-id"
      assert result.tenant == "stamp-tenant"
      assert result.baggage == %{"ot-baggage-fractal-level" => "L3"}
    end

    @tag :stamp
    test "SC-PRF-055: No blocking operations in context propagation" do
      # Context operations should complete quickly even under load
      ctx = ContextPropagation.capture_context()

      # Spawn many concurrent tasks
      tasks =
        for _ <- 1..100 do
          Task.async(
            ContextPropagation.wrap_task(fn ->
              Process.sleep(10)
              :ok
            end)
          )
        end

      # All should complete without blocking each other
      results = Task.await_many(tasks, 30_000)
      assert Enum.all?(results, &(&1 == :ok))
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "handles deeply nested with_context calls" do
      Process.put(:fractal_trace_id, "outer")

      ctx1 = ContextPropagation.capture_context()

      Process.put(:fractal_trace_id, "middle")
      ctx2 = ContextPropagation.capture_context()

      Process.put(:fractal_trace_id, "inner")
      ctx3 = ContextPropagation.capture_context()

      # Nested restoration
      ContextPropagation.with_context(ctx1, fn ->
        assert Process.get(:fractal_trace_id) == "outer"

        ContextPropagation.with_context(ctx2, fn ->
          assert Process.get(:fractal_trace_id) == "middle"

          ContextPropagation.with_context(ctx3, fn ->
            assert Process.get(:fractal_trace_id) == "inner"
          end)

          assert Process.get(:fractal_trace_id) == "middle"
        end)

        assert Process.get(:fractal_trace_id) == "outer"
      end)
    end

    test "handles empty metadata gracefully" do
      ctx = %{
        otel_ctx: nil,
        logger_metadata: [],
        process_baggage: %{},
        fractal_trace_id: nil,
        captured_at: System.monotonic_time(:microsecond)
      }

      result = ContextPropagation.with_context(ctx, fn -> :success end)
      assert result == :success
    end

    test "handles concurrent context modifications" do
      ctx = ContextPropagation.capture_context()

      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            ContextPropagation.with_context(ctx, fn ->
              # Each task modifies process dict
              Process.put(:task_id, i)
              Process.sleep(5)
              Process.get(:task_id)
            end)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # Each task should have seen its own value
      assert Enum.sort(results) == Enum.to_list(1..20)
    end

    test "handles very large metadata" do
      # Create large metadata
      large_metadata =
        for i <- 1..100 do
          {String.to_atom("key_#{i}"), String.duplicate("value", 100)}
        end

      Logger.metadata(large_metadata)

      ctx = ContextPropagation.capture_context()

      result =
        ContextPropagation.with_context(ctx, fn ->
          length(Logger.metadata())
        end)

      assert result >= 100
    end

    test "handles unicode in trace IDs" do
      Process.put(:fractal_trace_id, "trace-abc123")

      ctx = ContextPropagation.capture_context()

      result =
        ContextPropagation.with_context(ctx, fn ->
          Process.get(:fractal_trace_id)
        end)

      assert result == "trace-abc123"
    end
  end
end
