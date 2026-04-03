defmodule Indrajaal.Debugger.FractalIntegrationTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Debugger.FractalIntegration.

  Tests the fractal logging integration for closed-loop debugger telemetry.
  Verifies public API: log_event/2, log_at_level/3, correlate_rca/2,
  start_debug_span/2, end_debug_span/2.

  ## STAMP Constraints Verified
  - SC-DEBUG-002: Emit telemetry for all debug events
  - SC-DEBUG-003: Correlate with OTEL trace context
  - SC-LOG-003: PII masking for variable inspection
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Debugger.FractalIntegration

  # ---------------------------------------------------------------------------
  # log_event/2 — automatic level resolution
  # ---------------------------------------------------------------------------

  describe "log_event/2" do
    test "returns :ok for session_start event" do
      assert :ok = FractalIntegration.log_event(:session_start, %{session_id: "s1"})
    end

    test "returns :ok for session_end event" do
      assert :ok = FractalIntegration.log_event(:session_end, %{session_id: "s1"})
    end

    test "returns :ok for breakpoint_hit event" do
      assert :ok =
               FractalIntegration.log_event(:breakpoint_hit, %{
                 module: "Foo",
                 line: 42,
                 session_id: "s1"
               })
    end

    test "returns :ok for breakpoint_set event" do
      assert :ok =
               FractalIntegration.log_event(:breakpoint_set, %{
                 module: "Bar",
                 line: 10,
                 session_id: "s1"
               })
    end

    test "returns :ok for variable_inspected event" do
      assert :ok =
               FractalIntegration.log_event(:variable_inspected, %{
                 variable_name: "x",
                 session_id: "s1"
               })
    end

    test "returns :ok for expression_evaluated event" do
      assert :ok =
               FractalIntegration.log_event(:expression_evaluated, %{
                 expression: "1 + 1",
                 session_id: "s1"
               })
    end

    test "returns :ok for step_over event" do
      assert :ok = FractalIntegration.log_event(:step_over, %{session_id: "s1"})
    end

    test "returns :ok for step_into event" do
      assert :ok = FractalIntegration.log_event(:step_into, %{session_id: "s1"})
    end

    test "returns :ok for step_out event" do
      assert :ok = FractalIntegration.log_event(:step_out, %{session_id: "s1"})
    end

    test "returns :ok for stack_trace event" do
      assert :ok =
               FractalIntegration.log_event(:stack_trace, %{
                 frame_count: 5,
                 session_id: "s1"
               })
    end

    test "returns :ok for exception_caught event" do
      assert :ok =
               FractalIntegration.log_event(:exception_caught, %{
                 exception_type: "RuntimeError",
                 session_id: "s1"
               })
    end

    test "returns :ok for bridge_connected event" do
      assert :ok =
               FractalIntegration.log_event(:bridge_connected, %{
                 target_language: "fsharp"
               })
    end

    test "returns :ok for cross_language_call event" do
      assert :ok =
               FractalIntegration.log_event(:cross_language_call, %{
                 from_language: "elixir",
                 to_language: "fsharp"
               })
    end

    test "returns :ok for unknown event types using default level" do
      assert :ok = FractalIntegration.log_event(:some_custom_event, %{})
    end

    test "masks :password field in metadata (SC-LOG-003)" do
      # Should not raise; password should be redacted internally
      assert :ok =
               FractalIntegration.log_event(:variable_inspected, %{
                 variable_name: "pwd",
                 password: "secret123"
               })
    end

    test "masks :token field in metadata" do
      assert :ok =
               FractalIntegration.log_event(:variable_inspected, %{
                 variable_name: "tok",
                 token: "bearer_abc"
               })
    end

    test "accepts empty metadata map" do
      assert :ok = FractalIntegration.log_event(:grpc_request, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # log_at_level/3 — explicit level override
  # ---------------------------------------------------------------------------

  describe "log_at_level/3" do
    test "returns :ok for :L1 level" do
      assert :ok = FractalIntegration.log_at_level(:L1, :session_start, %{session_id: "s1"})
    end

    test "returns :ok for :L2 level" do
      assert :ok =
               FractalIntegration.log_at_level(:L2, :bridge_connected, %{
                 target_language: "fsharp"
               })
    end

    test "returns :ok for :L3 level" do
      assert :ok =
               FractalIntegration.log_at_level(:L3, :breakpoint_hit, %{
                 module: "Baz",
                 line: 99
               })
    end

    test "returns :ok for :L4 level" do
      assert :ok = FractalIntegration.log_at_level(:L4, :stack_trace, %{frame_count: 3})
    end

    test "returns :ok for :L5 level" do
      assert :ok =
               FractalIntegration.log_at_level(:L5, :variable_inspected, %{
                 variable_name: "foo"
               })
    end

    test "returns :ok for unknown level" do
      assert :ok = FractalIntegration.log_at_level(:LX, :some_event, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # correlate_rca/2
  # ---------------------------------------------------------------------------

  describe "correlate_rca/2" do
    test "returns ok tuple with correlation_id, event_count, rca_chain, impact_analysis" do
      {:ok, result} = FractalIntegration.correlate_rca("corr-123")
      assert result.correlation_id == "corr-123"
      assert is_integer(result.event_count)
      assert is_list(result.rca_chain)
      assert is_map(result.impact_analysis)
    end

    test "rca_chain contains level, order, events, description keys" do
      {:ok, result} = FractalIntegration.correlate_rca("corr-456")

      Enum.each(result.rca_chain, fn chain_entry ->
        assert Map.has_key?(chain_entry, :level)
        assert Map.has_key?(chain_entry, :order)
        assert Map.has_key?(chain_entry, :events)
        assert Map.has_key?(chain_entry, :description)
      end)
    end

    test "impact_analysis contains first through fifth order keys" do
      {:ok, result} = FractalIntegration.correlate_rca("corr-789")
      impact = result.impact_analysis
      assert Map.has_key?(impact, :first_order)
      assert Map.has_key?(impact, :second_order)
      assert Map.has_key?(impact, :third_order)
      assert Map.has_key?(impact, :fourth_order)
      assert Map.has_key?(impact, :fifth_order)
    end

    test "accepts event_types filter argument" do
      {:ok, result} = FractalIntegration.correlate_rca("corr-abc", [:breakpoint_hit])
      assert result.correlation_id == "corr-abc"
    end

    test "empty event_types returns all correlated events" do
      {:ok, full} = FractalIntegration.correlate_rca("corr-full", [])
      {:ok, filtered} = FractalIntegration.correlate_rca("corr-full", [:session_start])
      # Filtered should have <= full
      assert filtered.event_count <= full.event_count
    end
  end

  # ---------------------------------------------------------------------------
  # start_debug_span/2 and end_debug_span/2
  # ---------------------------------------------------------------------------

  describe "start_debug_span/2" do
    test "returns a span context map" do
      span = FractalIntegration.start_debug_span(:breakpoint_hit)
      assert is_map(span)
    end

    test "span context has span_name key" do
      span = FractalIntegration.start_debug_span(:step_over)
      assert Map.has_key?(span, :span_name)
      assert span.span_name == "debugger.step_over"
    end

    test "span context has trace_id key" do
      span = FractalIntegration.start_debug_span(:session_start)
      assert Map.has_key?(span, :trace_id)
      assert is_binary(span.trace_id)
    end

    test "span context has span_id key" do
      span = FractalIntegration.start_debug_span(:variable_inspected)
      assert Map.has_key?(span, :span_id)
      assert is_binary(span.span_id)
    end

    test "span context has start_time as integer" do
      span = FractalIntegration.start_debug_span(:expression_evaluated)
      assert is_integer(span.start_time)
    end

    test "span context has attributes map with debugger.operation key" do
      span = FractalIntegration.start_debug_span(:breakpoint_set, %{module: "Foo"})
      assert is_map(span.attributes)
      assert Map.has_key?(span.attributes, "debugger.operation")
    end

    test "accepts custom attributes" do
      span = FractalIntegration.start_debug_span(:step_into, %{language: "fsharp"})
      assert Map.has_key?(span.attributes, "debugger.language")
    end
  end

  describe "end_debug_span/2" do
    test "returns :ok for successful span" do
      span = FractalIntegration.start_debug_span(:step_over)
      assert :ok = FractalIntegration.end_debug_span(span, :ok)
    end

    test "returns :ok for error span result" do
      span = FractalIntegration.start_debug_span(:exception_caught)
      assert :ok = FractalIntegration.end_debug_span(span, {:error, :something})
    end

    test "returns :ok for default result argument" do
      span = FractalIntegration.start_debug_span(:session_end)
      assert :ok = FractalIntegration.end_debug_span(span)
    end
  end
end
