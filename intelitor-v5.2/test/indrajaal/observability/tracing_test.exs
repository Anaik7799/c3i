defmodule Indrajaal.Observability.TracingTest do
  @moduledoc """
  Test suite for distributed tracing enhancements.

  This module tests:
  - Span creation and management
  - Context propagation across processes and nodes
  - Trace sampling strategies
  - Baggage items and propagation
  - Integration with OpenTelemetry
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Tracing

  describe "span management" do
    test "creates spans with proper attributes" do
      # When creating a span
      span =
        Tracing.start_span("user.login", %{
          "user.id" => 123,
          "auth.method" => "password",
          "service.name" => "accounts"
        })

      # Then span should have correct structure
      assert span.name == "user.login"
      assert span.trace_id != nil
      assert span.span_id != nil
      assert span.attributes["user.id"] == 123
      assert span.attributes["auth.method"] == "password"
      assert span.attributes["service.name"] == "accounts"
      assert span.start_time != nil
    end

    test "creates child spans with proper parent relationship" do
      # Given a parent span
      parent = Tracing.start_span("parent.operation")

      # When creating child span
      child =
        Tracing.with_span(parent, fn ->
          Tracing.start_span("child.operation")
        end)

      # Then relationship should be established
      assert child.trace_id == parent.trace_id
      assert child.parent_span_id == parent.span_id
      assert child.span_id != parent.span_id
    end

    test "automatically ends spans with duration" do
      # When using with_span block
      {result, span} =
        Tracing.with_span("timed.operation", fn ->
          Process.sleep(50)
          {:ok, "result"}
        end)

      # Then span should be ended with duration
      assert result == {:ok, "result"}
      assert span.end_time != nil
      # 50ms in nanoseconds
      assert span.duration_ns >= 50_000_000
    end

    test "records span events" do
      # Given an active span
      span = Tracing.start_span("eventful.operation")

      # When adding events
      Tracing.add_event(span, "user.authenticated", %{"method" => "oauth"})
      Process.sleep(10)
      Tracing.add_event(span, "permission.checked", %{"resource" => "orders"})
      Process.sleep(10)
      Tracing.add_event(span, "operation.completed", %{"status" => "success"})

      # Then events should be recorded
      ended_span = Tracing.end_span(span)
      assert length(ended_span.events) == 3

      assert Enum.map(ended_span.events, & &1.name) == [
               "user.authenticated",
               "permission.checked",
               "operation.completed"
             ]
    end

    test "sets span status correctly" do
      # When span succeeds
      success_span_result =
        Tracing.with_span("success.op", fn ->
          :ok
        end)

      success_span = success_span_result |> elem(1)

      # When span has error
      error_span =
        try do
          Tracing.with_span("error.op", fn ->
            raise "Operation failed"
          end)
        rescue
          _ -> Tracing.get_current_span()
        end

      # Then status should reflect outcome
      assert success_span.status.code == :ok
      assert error_span.status.code == :error
      assert error_span.status.description =~ "Operation failed"
    end
  end

  describe "context propagation" do
    test "propagates trace context across processes" do
      # Given a trace context
      parent_span = Tracing.start_span("parent.process")

      # When spawning child process
      task_result =
        Task.async(fn ->
          # Context should be automatically propagated
          child_span = Tracing.start_span("child.process")
          {child_span.trace_id, child_span.parent_span_id}
        end)

      child_trace = task_result |> Task.await()

      # Then trace should be connected
      {child_trace_id, child_parent_id} = child_trace
      assert child_trace_id == parent_span.trace_id
      assert child_parent_id == parent_span.span_id
    end

    test "propagates context through message passing" do
      # Given a process with trace context
      parent_span = Tracing.start_span("sender")

      # When sending message with context
      receiver_pid =
        spawn(fn ->
          receive do
            {:work, received_context} ->
              Tracing.with_context(received_context, fn ->
                span = Tracing.start_span("receiver")
                send(self(), {:span_info, span.trace_id, span.parent_span_id})
              end)
          end
        end)

      trace_context = Tracing.extract_context()
      send(receiver_pid, {:work, trace_context})

      # Then receiver should have proper context
      assert_receive {:span_info, trace_id, parent_id}
      assert trace_id == parent_span.trace_id
      assert parent_id == parent_span.span_id
    end

    test "propagates context via HTTP headers" do
      # Given a span
      span = Tracing.start_span("http.client")

      # When injecting into headers
      headers = Tracing.inject_http_headers([])

      # Then headers should contain trace context
      assert {"traceparent", traceparent} = List.keyfind(headers, "traceparent", 0)
      assert traceparent =~ ~r/00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9]{2}/

      # When extracting from headers on server side
      extracted_context = Tracing.extract_http_headers(headers)

      server_span =
        Tracing.with_context(extracted_context, fn ->
          Tracing.start_span("http.server")
        end)

      # Then context should be preserved
      assert server_span.trace_id == span.trace_id
      assert server_span.parent_span_id == span.span_id
    end

    test "supports W3C trace context format" do
      # Given W3C formatted headers
      headers = [
        {"traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"},
        {"tracestate", "congo=t61rcWkgMzE"}
      ]

      # When extracting context
      w3c_context = Tracing.extract_http_headers(headers)

      span =
        Tracing.with_context(w3c_context, fn ->
          Tracing.start_span("w3c.test")
        end)

      # Then values should be parsed correctly
      assert span.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736"
      assert span.parent_span_id == "00f067aa0ba902b7"
      # sampled
      assert span.trace_flags == 1
      assert span.trace_state["congo"] == "t61rcWkgMzE"
    end
  end

  describe "trace sampling" do
    test "applies probability sampling" do
      # Given 10% sampling rate
      Tracing.configure_sampling(probability: 0.1)

      # When creating many traces
      sampling_results =
        Enum.map(1..1000, fn _ ->
          span = Tracing.start_span("sampled.operation")
          span.sampled
        end)

      # Then approximately 10% should be sampled
      sampled_count = Enum.count(sampling_results, & &1)
      assert sampled_count > 80 and sampled_count < 120
    end

    test "always samples error spans" do
      # Given low sampling rate
      Tracing.configure_sampling(probability: 0.01)

      # When span has error
      error_spans =
        Enum.map(1..10, fn _ ->
          try do
            Tracing.with_span("error.test", fn ->
              raise "Test error"
            end)
          rescue
            _ -> Tracing.get_current_span()
          end
        end)

      # Then all error spans should be sampled
      assert Enum.all?(error_spans, & &1.sampled)
    end

    test "supports custom sampling decisions" do
      # Given custom sampler
      Tracing.configure_sampling(
        sampler: fn span_name, attributes ->
          # Sample all admin operations
          # Sample slow operations
          attributes["user.role"] == "admin" or
            attributes["expected.duration"] > 1000
        end
      )

      # When creating spans with different attributes
      admin_span = Tracing.start_span("admin.operation", %{"user.role" => "admin"})
      slow_span = Tracing.start_span("slow.operation", %{"expected.duration" => 5000})
      normal_span = Tracing.start_span("normal.operation", %{"user.role" => "user"})

      # Then sampling should follow rules
      assert admin_span.sampled == true
      assert slow_span.sampled == true
      assert normal_span.sampled == false
    end

    test "propagates sampling decision through trace" do
      # Given a sampled parent
      parent = Tracing.start_span("parent", %{}, sampled: true)

      # When creating descendants
      child =
        Tracing.with_span(parent, fn ->
          Tracing.start_span("child")
        end)

      grandchild =
        Tracing.with_span(child, fn ->
          Tracing.start_span("grandchild")
        end)

      # Then all should be sampled
      assert parent.sampled == true
      assert child.sampled == true
      assert grandchild.sampled == true
    end
  end

  describe "baggage propagation" do
    test "propagates baggage items through trace" do
      # Given baggage items
      Tracing.set_baggage("user.id", "123")
      Tracing.set_baggage("tenant.id", "tenant_456")

      # When creating child spans
      span1 = Tracing.start_span("operation1")
      span2 = Tracing.start_span("operation2")

      # Then baggage should be accessible
      assert Tracing.get_baggage("user.id") == "123"
      assert Tracing.get_baggage("tenant.id") == "tenant_456"
      assert span1.baggage["user.id"] == "123"
      assert span2.baggage["tenant.id"] == "tenant_456"
    end

    test "baggage survives process boundaries" do
      # Given baggage in parent process
      Tracing.set_baggage("session.id", "sess_789")

      # When spawning child process
      task =
        Task.async(fn ->
          Tracing.get_baggage("session.id")
        end)

      baggage_value = task |> Task.await()

      # Then baggage should be propagated
      assert baggage_value == "sess_789"
    end

    test "includes baggage in HTTP headers" do
      # Given baggage items
      Tracing.set_baggage("user.tier", "premium")
      Tracing.set_baggage("feature.flags", "new_ui,dark_mode")

      # When injecting headers
      headers = Tracing.inject_http_headers([])

      # Then baggage should be included
      assert {"baggage", baggage_header} = List.keyfind(headers, "baggage", 0)
      assert baggage_header =~ "user.tier=premium"
      assert baggage_header =~ "feature.flags=new_ui%2Cdark_mode"
    end

    test "limits baggage size" do
      # When trying to set large baggage
      large_value = String.duplicate("x", 10_000)
      result = Tracing.set_baggage("large.item", large_value)

      # Then it should be rejected
      assert {:error, :baggage_too_large} = result
      assert Tracing.get_baggage("large.item") == nil
    end
  end

  describe "OpenTelemetry integration" do
    test "exports spans in OTLP format" do
      # Given completed spans
      span =
        Tracing.start_span("export.test", %{
          "service.name" => "indrajaal",
          "service.version" => "1.0.0"
        })

      Tracing.add_event(span, "checkpoint", %{"progress" => 50})
      ended_span = Tracing.end_span(span)

      # When exporting to OTLP
      otlp_data = Tracing.export_otlp([ended_span])

      # Then format should be correct
      assert otlp_data.resource_spans != nil
      resource_span = hd(otlp_data.resource_spans)
      assert resource_span.resource.attributes["service.name"] == "indrajaal"

      scope_span = hd(resource_span.scope_spans)
      span_data = hd(scope_span.spans)
      assert span_data.name == "export.test"
      assert length(span_data.events) == 1
    end

    test "batches span exports efficiently" do
      # Given many spans
      batch_spans =
        Enum.map(1..100, fn i ->
          span = Tracing.start_span("batch.test.#{i}")
          Tracing.end_span(span)
        end)

      # When configuring batch export
      Tracing.configure_export(
        batch_size: 25,
        export_interval: 100,
        exporter: fn batch ->
          send(self(), {:exported_batch, length(batch)})
        end
      )

      # And triggering export
      Tracing.export_spans(batch_spans)

      # Then should export in batches
      assert_receive {:exported_batch, 25}
      assert_receive {:exported_batch, 25}
      assert_receive {:exported_batch, 25}
      assert_receive {:exported_batch, 25}
    end
  end

  describe "multi-tenant tracing" do
    test "isolates traces by tenant" do
      # Given traces for different tenants
      tenant1_span =
        Tracing.with_tenant("tenant_1", fn ->
          Tracing.start_span("tenant1.operation")
        end)

      tenant2_span =
        Tracing.with_tenant("tenant_2", fn ->
          Tracing.start_span("tenant2.operation")
        end)

      # Then traces should be isolated
      assert tenant1_span.attributes["tenant.id"] == "tenant_1"
      assert tenant2_span.attributes["tenant.id"] == "tenant_2"
      assert tenant1_span.trace_id != tenant2_span.trace_id
    end

    test "enforces tenant boundaries in trace viewing" do
      # Given a trace from tenant 1
      Tracing.with_tenant("tenant_1", fn ->
        span = Tracing.start_span("secure.operation")
        Tracing.store_span(span)
      end)

      # When tenant 2 tries to access
      result =
        Tracing.with_tenant("tenant_2", fn ->
          Tracing.get_stored_spans(trace_id: "any")
        end)

      # Then access should be denied
      assert {:error, :unauthorized} = result
    end
  end

  describe "STAMP safety constraints" do
    test "limits trace depth to prevent stack overflow" do
      # When creating deeply nested traces
      create_nested_span = fn create_nested_span, depth ->
        if depth > 0 do
          Tracing.with_span("level.#{depth}", fn ->
            create_nested_span.(create_nested_span, depth - 1)
          end)
        else
          Tracing.get_current_span()
        end
      end

      # Then depth should be limited
      deepest = create_nested_span.(create_nested_span, 100)
      trace = Tracing.get_full_trace(deepest.trace_id)
      assert length(trace.spans) <= Tracing.max_trace_depth()
    end

    test "prevents trace attribute explosion" do
      # When trying to add many attributes
      attributes = Map.new(1..1000, fn i -> {"attr_#{i}", "value_#{i}"} end)

      span = Tracing.start_span("attr.explosion", attributes)

      # Then attributes should be limited
      assert map_size(span.attributes) <= Tracing.max_attributes_per_span()
      assert span.attributes["_truncated"] == true
    end

    test "implements trace timeout" do
      # Given a long-running trace
      span = Tracing.start_span("timeout.test")

      # When trace exceeds timeout
      Process.sleep(Tracing.max_span_duration() + 100)

      # Then span should be auto-ended
      stored = Tracing.get_span(span.span_id)
      assert stored.ended == true
      assert stored.status.code == :deadline_exceeded
    end
  end
end
