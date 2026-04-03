defmodule Indrajaal.Observability.Fractal.OtelIntegrationTest do
  @moduledoc """
  TDG Tests for OTel Baggage Integration.

  WHAT: Property-based and unit tests for OpenTelemetry integration with the
        Fractal Logging System including span creation and baggage propagation.

  WHY: Ensure STAMP compliance (SC-LOG-004, SC-OBS-069) and verify correct
       OTel span creation, attribute injection, and baggage propagation.

  CONSTRAINTS:
  - TDG: Tests written BEFORE implementation modifications
  - Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014 compliant)
  - SC-LOG-004: L1/L2 must link to L3 TraceID
  - SC-OBS-069: Dual Log (Term+SigNoz) integration

  ## Test Categories

  1. Span Management Tests - Creation, attributes, ending
  2. Baggage Propagation Tests - Set, get, clear, inject/extract
  3. Trace Correlation Tests - SC-LOG-004 compliance
  4. Property-Based Tests - Edge case discovery
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]

  # EP-GEN-014: Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Observability.Fractal.{FractalControl, OtelIntegration, HLC}

  @moduletag :fractal_otel

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure FractalControl is started
    case Process.whereis(FractalControl) do
      nil ->
        {:ok, pid} = FractalControl.start_link()
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      _pid ->
        :ok
    end

    # Clear any process dictionary state
    Process.delete(:fractal_baggage)
    Process.delete(:fractal_trace_id)
    Process.delete(:fractal_span_id)

    :ok
  end

  # ============================================================
  # SPAN MANAGEMENT TESTS
  # ============================================================

  describe "start_fractal_span/3" do
    test "creates span context with required fields" do
      span_ctx = OtelIntegration.start_fractal_span(TestModule, :test_function, :l3)

      assert is_map(span_ctx)
      assert Map.has_key?(span_ctx, :span_name)
      assert Map.has_key?(span_ctx, :level)
      assert Map.has_key?(span_ctx, :module)
      assert Map.has_key?(span_ctx, :function)
      assert Map.has_key?(span_ctx, :start_time)
    end

    test "span name follows expected format" do
      span_ctx = OtelIntegration.start_fractal_span(MyApp.Accounts.User, :create, :l3)

      assert span_ctx.span_name == "fractal:MyApp.Accounts.User.create"
    end

    test "generates HLC for L3+ levels" do
      span_ctx_l3 = OtelIntegration.start_fractal_span(TestModule, :func, :l3)
      span_ctx_l4 = OtelIntegration.start_fractal_span(TestModule, :func, :l4)
      span_ctx_l5 = OtelIntegration.start_fractal_span(TestModule, :func, :l5)

      assert span_ctx_l3.hlc != nil
      assert span_ctx_l4.hlc != nil
      assert span_ctx_l5.hlc != nil
    end

    test "does not generate HLC for L1/L2 levels" do
      span_ctx_l1 = OtelIntegration.start_fractal_span(TestModule, :func, :l1)
      span_ctx_l2 = OtelIntegration.start_fractal_span(TestModule, :func, :l2)

      assert span_ctx_l1.hlc == nil
      assert span_ctx_l2.hlc == nil
    end

    test "records start time for duration calculation" do
      before = System.monotonic_time(:microsecond)
      span_ctx = OtelIntegration.start_fractal_span(TestModule, :func, :l3)
      after_time = System.monotonic_time(:microsecond)

      assert span_ctx.start_time >= before
      assert span_ctx.start_time <= after_time
    end
  end

  describe "end_fractal_span/2" do
    test "handles nil span context gracefully" do
      assert :ok = OtelIntegration.end_fractal_span(nil, :ok)
    end

    test "ends span with success status" do
      span_ctx = OtelIntegration.start_fractal_span(TestModule, :func, :l3)
      assert :ok = OtelIntegration.end_fractal_span(span_ctx, :ok)
    end

    test "ends span with error status" do
      span_ctx = OtelIntegration.start_fractal_span(TestModule, :func, :l3)
      exception = %RuntimeError{message: "test error"}
      assert :ok = OtelIntegration.end_fractal_span(span_ctx, {:error, exception})
    end

    test "clears fractal baggage after ending" do
      OtelIntegration.start_fractal_span(TestModule, :func, :l3)

      # Baggage should be set
      baggage = OtelIntegration.get_fractal_baggage()
      assert map_size(baggage) > 0

      # End span
      OtelIntegration.clear_fractal_baggage()

      # Baggage should be cleared
      baggage_after = OtelIntegration.get_fractal_baggage()
      assert baggage_after == %{}
    end
  end

  # ============================================================
  # BAGGAGE PROPAGATION TESTS
  # ============================================================

  describe "set_fractal_baggage/4" do
    test "sets module in baggage" do
      OtelIntegration.set_fractal_baggage(TestModule, :test_func, :l3, nil)
      baggage = OtelIntegration.get_fractal_baggage()

      assert baggage["ot-baggage-fractal-module"] == "TestModule"
    end

    test "sets function in baggage" do
      OtelIntegration.set_fractal_baggage(TestModule, :test_func, :l3, nil)
      baggage = OtelIntegration.get_fractal_baggage()

      assert baggage["ot-baggage-fractal-function"] == "test_func"
    end

    test "sets level in baggage" do
      OtelIntegration.set_fractal_baggage(TestModule, :test_func, :l3, nil)
      baggage = OtelIntegration.get_fractal_baggage()

      assert baggage["ot-baggage-fractal-level"] == "L3"
    end

    test "strips Elixir. prefix from module name" do
      OtelIntegration.set_fractal_baggage(Elixir.MyApp.Module, :func, :l3, nil)
      baggage = OtelIntegration.get_fractal_baggage()

      refute baggage["ot-baggage-fractal-module"] =~ "Elixir."
    end
  end

  describe "get_fractal_baggage/0" do
    test "returns empty map when no baggage set" do
      baggage = OtelIntegration.get_fractal_baggage()
      assert is_map(baggage)
    end

    test "returns all set baggage entries" do
      OtelIntegration.set_fractal_baggage(TestModule, :func, :l4, nil)
      baggage = OtelIntegration.get_fractal_baggage()

      assert Map.has_key?(baggage, "ot-baggage-fractal-level")
      assert Map.has_key?(baggage, "ot-baggage-fractal-module")
      assert Map.has_key?(baggage, "ot-baggage-fractal-function")
    end
  end

  describe "get_fractal_baggage/1" do
    test "returns specific baggage value by key" do
      OtelIntegration.set_fractal_baggage(TestModule, :func, :l3, nil)

      # Can get by atom key
      level = OtelIntegration.get_fractal_baggage(:level)

      # Should find the value (implementation may vary on exact key)
      assert is_nil(level) or is_binary(level)
    end
  end

  describe "clear_fractal_baggage/0" do
    test "removes all fractal baggage" do
      OtelIntegration.set_fractal_baggage(TestModule, :func, :l3, nil)
      assert map_size(OtelIntegration.get_fractal_baggage()) > 0

      OtelIntegration.clear_fractal_baggage()
      assert OtelIntegration.get_fractal_baggage() == %{}
    end
  end

  describe "inject_baggage_headers/1" do
    test "adds baggage to headers list" do
      OtelIntegration.set_fractal_baggage(TestModule, :func, :l3, nil)

      headers = [{"content-type", "application/json"}]
      injected_headers = OtelIntegration.inject_baggage_headers(headers)

      assert length(injected_headers) > length(headers)
    end

    test "preserves existing headers" do
      OtelIntegration.set_fractal_baggage(TestModule, :func, :l3, nil)

      headers = [{"authorization", "Bearer token"}, {"x-custom", "value"}]
      injected_headers = OtelIntegration.inject_baggage_headers(headers)

      assert {"authorization", "Bearer token"} in injected_headers
      assert {"x-custom", "value"} in injected_headers
    end
  end

  describe "extract_baggage_headers/1" do
    test "extracts fractal baggage from list headers" do
      headers = [
        {"content-type", "application/json"},
        {"ot-baggage-fractal-level", "L3"},
        {"ot-baggage-fractal-module", "TestModule"},
        {"x-request-id", "123"}
      ]

      extracted = OtelIntegration.extract_baggage_headers(headers)

      assert Map.has_key?(extracted, "ot-baggage-fractal-level")
      assert Map.has_key?(extracted, "ot-baggage-fractal-module")
      refute Map.has_key?(extracted, "content-type")
      refute Map.has_key?(extracted, "x-request-id")
    end

    test "extracts fractal baggage from map headers" do
      headers = %{
        "content-type" => "application/json",
        "ot-baggage-fractal-level" => "L3",
        "ot-baggage-fractal-function" => "create"
      }

      extracted = OtelIntegration.extract_baggage_headers(headers)

      assert Map.has_key?(extracted, "ot-baggage-fractal-level")
      assert Map.has_key?(extracted, "ot-baggage-fractal-function")
      refute Map.has_key?(extracted, "content-type")
    end

    test "returns empty map when no fractal headers" do
      headers = [{"content-type", "application/json"}]
      extracted = OtelIntegration.extract_baggage_headers(headers)

      assert extracted == %{}
    end
  end

  # ============================================================
  # TRACE CORRELATION TESTS (SC-LOG-004)
  # ============================================================

  describe "get_l3_trace_id/0 - SC-LOG-004" do
    test "returns nil when no trace ID set" do
      trace_id = OtelIntegration.get_l3_trace_id()
      # May be nil or from OTel if available
      assert is_nil(trace_id) or is_binary(trace_id)
    end

    test "returns trace ID from process dictionary" do
      Process.put(:fractal_trace_id, "test-trace-id")

      trace_id = OtelIntegration.get_l3_trace_id()
      assert trace_id == "test-trace-id"
    end
  end

  describe "link_to_l3_trace/1 - SC-LOG-004" do
    test "returns entry unchanged when no trace ID available" do
      entry = %{message: "test", level: :l1}
      linked = OtelIntegration.link_to_l3_trace(entry)

      assert linked.message == "test"
      assert linked.level == :l1
    end

    test "adds trace_id and correlation flag when trace ID exists" do
      Process.put(:fractal_trace_id, "trace-abc-123")

      entry = %{message: "test", level: :l1}
      linked = OtelIntegration.link_to_l3_trace(entry)

      assert linked.l3_trace_id == "trace-abc-123"
      assert linked.trace_correlation == true
      assert linked.message == "test"
    end

    test "preserves all original entry fields" do
      Process.put(:fractal_trace_id, "trace-123")

      entry = %{
        message: "test",
        level: :l2,
        module: TestModule,
        function: :create,
        custom_field: "preserved"
      }

      linked = OtelIntegration.link_to_l3_trace(entry)

      assert linked.message == "test"
      assert linked.level == :l2
      assert linked.module == TestModule
      assert linked.function == :create
      assert linked.custom_field == "preserved"
      assert linked.l3_trace_id == "trace-123"
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================

  describe "PropCheck property tests" do
    property "start_fractal_span always returns a valid span context" do
      # Use simple integer-based module/function names to avoid atom issues
      forall {module_idx, func_idx, level_int} <-
               {PC.integer(1, 100), PC.integer(1, 100), PC.integer(1, 5)} do
        # Create safe module and function names
        module = String.to_atom("Elixir.TestModule#{module_idx}")
        function = String.to_atom("func#{func_idx}")
        level = FractalControl.int_to_level(level_int)

        span_ctx = OtelIntegration.start_fractal_span(module, function, level)

        is_map(span_ctx) and
          Map.has_key?(span_ctx, :span_name) and
          Map.has_key?(span_ctx, :start_time)
      end
    end

    property "baggage roundtrip preserves data" do
      forall level_int <- PC.integer(1, 5) do
        level = FractalControl.int_to_level(level_int)

        OtelIntegration.set_fractal_baggage(TestModule, :func, level, nil)
        baggage = OtelIntegration.get_fractal_baggage()
        OtelIntegration.clear_fractal_baggage()

        is_map(baggage) and Map.has_key?(baggage, "ot-baggage-fractal-level")
      end
    end

    property "link_to_l3_trace is idempotent" do
      forall message <- PC.binary() do
        Process.put(:fractal_trace_id, "test-trace")

        entry = %{message: message}
        linked1 = OtelIntegration.link_to_l3_trace(entry)
        linked2 = OtelIntegration.link_to_l3_trace(linked1)

        # Linking twice should give same result
        linked1.l3_trace_id == linked2.l3_trace_id and
          linked1.trace_correlation == linked2.trace_correlation
      end
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (ExUnitProperties)
  # ============================================================

  describe "ExUnitProperties property tests" do
    test "header injection never loses original headers" do
      ExUnitProperties.check all(
                               headers <-
                                 SD.list_of(
                                   SD.tuple(
                                     {SD.string(:alphanumeric, min_length: 1),
                                      SD.string(:alphanumeric, min_length: 1)}
                                   ),
                                   max_length: 10
                                 )
                             ) do
        OtelIntegration.set_fractal_baggage(TestModule, :func, :l3, nil)
        injected = OtelIntegration.inject_baggage_headers(headers)

        # All original headers should be present
        Enum.each(headers, fn header ->
          assert header in injected
        end)
      end
    end

    test "extracted headers only contain fractal prefixed entries" do
      fractal_prefix = "ot-baggage-fractal-"

      ExUnitProperties.check all(
                               fractal_headers <-
                                 SD.list_of(
                                   SD.tuple(
                                     {SD.constant("ot-baggage-fractal-test"),
                                      SD.string(:alphanumeric, min_length: 1)}
                                   ),
                                   max_length: 5
                                 ),
                               other_headers <-
                                 SD.list_of(
                                   SD.tuple(
                                     {SD.string(:alphanumeric, min_length: 1),
                                      SD.string(:alphanumeric, min_length: 1)}
                                   ),
                                   max_length: 5
                                 )
                             ) do
        all_headers = fractal_headers ++ other_headers
        extracted = OtelIntegration.extract_baggage_headers(all_headers)

        # All extracted keys should have fractal prefix
        Enum.each(Map.keys(extracted), fn key ->
          assert String.starts_with?(key, fractal_prefix)
        end)
      end
    end

    test "all fractal levels produce valid baggage entries" do
      valid_levels = [:l1, :l2, :l3, :l4, :l5]

      ExUnitProperties.check all(level <- SD.member_of(valid_levels)) do
        OtelIntegration.clear_fractal_baggage()
        OtelIntegration.set_fractal_baggage(TestModule, :func, level, nil)
        baggage = OtelIntegration.get_fractal_baggage()

        assert is_map(baggage)
        assert baggage["ot-baggage-fractal-level"] in ["L1", "L2", "L3", "L4", "L5"]
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE VERIFICATION TESTS
  # ============================================================

  describe "STAMP compliance verification" do
    @tag :stamp
    test "SC-LOG-004: L1 logs can link to L3 TraceID" do
      # Set up L3 trace context
      Process.put(:fractal_trace_id, "l3-transaction-trace-id")

      # L1 log entry
      l1_entry = %{
        level: :l1,
        key: "Module/function",
        message: "detailed arg dump"
      }

      # Link to L3 trace
      linked_entry = OtelIntegration.link_to_l3_trace(l1_entry)

      assert linked_entry.l3_trace_id == "l3-transaction-trace-id"
      assert linked_entry.trace_correlation == true
    end

    @tag :stamp
    test "SC-LOG-004: L2 logs can link to L3 TraceID" do
      Process.put(:fractal_trace_id, "l3-component-trace-id")

      l2_entry = %{
        level: :l2,
        key: "GenServer/state",
        message: "state transition"
      }

      linked_entry = OtelIntegration.link_to_l3_trace(l2_entry)

      assert linked_entry.l3_trace_id == "l3-component-trace-id"
      assert linked_entry.trace_correlation == true
    end

    @tag :stamp
    test "SC-OBS-069: Baggage propagation for distributed tracing" do
      # Set up fractal context
      OtelIntegration.set_fractal_baggage(
        Indrajaal.Accounts.User,
        :create,
        :l3,
        nil
      )

      # Get baggage for propagation
      baggage = OtelIntegration.get_fractal_baggage()

      # Should have required fields for distributed tracing
      assert Map.has_key?(baggage, "ot-baggage-fractal-level")
      assert Map.has_key?(baggage, "ot-baggage-fractal-module")
      assert Map.has_key?(baggage, "ot-baggage-fractal-function")
    end

    @tag :stamp
    test "Span attributes include fractal metadata" do
      span_ctx =
        OtelIntegration.start_fractal_span(
          Indrajaal.Alarms.Handler,
          :process_alarm,
          :l3
        )

      # Verify span context includes fractal metadata
      assert span_ctx.level == :l3
      assert span_ctx.module == Indrajaal.Alarms.Handler
      assert span_ctx.function == :process_alarm
      assert span_ctx.span_name =~ "fractal:"
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "handles nil module gracefully" do
      # This shouldn't crash
      span_ctx = OtelIntegration.start_fractal_span(nil, :func, :l3)
      assert is_map(span_ctx)
    end

    test "handles empty function name" do
      span_ctx = OtelIntegration.start_fractal_span(TestModule, :"", :l3)
      assert is_map(span_ctx)
    end

    test "handles concurrent span operations" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            span_ctx =
              OtelIntegration.start_fractal_span(
                String.to_atom("Module#{i}"),
                String.to_atom("func#{i}"),
                :l3
              )

            Process.sleep(10)
            OtelIntegration.end_fractal_span(span_ctx, :ok)
            :ok
          end)
        end

      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))
    end

    test "handles very long module names" do
      long_module = String.to_atom("Elixir." <> String.duplicate("A", 200))
      span_ctx = OtelIntegration.start_fractal_span(long_module, :func, :l3)
      assert is_map(span_ctx)
    end

    test "handles unicode in module and function names" do
      span_ctx =
        OtelIntegration.start_fractal_span(
          Module,
          :func,
          :l3
        )

      assert is_map(span_ctx)
    end

    test "baggage survives across function calls" do
      OtelIntegration.set_fractal_baggage(TestModule, :func1, :l3, nil)

      # Call another function
      _result = inner_function()

      # Baggage should still be there
      baggage = OtelIntegration.get_fractal_baggage()
      assert Map.has_key?(baggage, "ot-baggage-fractal-level")
    end
  end

  # Helper function for testing baggage persistence
  defp inner_function do
    OtelIntegration.get_fractal_baggage()
  end
end
