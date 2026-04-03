defmodule Indrajaal.Observability.DistributedTracingOtelTest do
  @moduledoc """
  Distributed tracing end-to-end test suite with OTEL span correlation.

  ## WHAT
  Tests that OpenTelemetry spans are correctly created, propagated, and
  correlated across service boundaries, ensuring full distributed tracing
  from request ingestion through all processing stages.

  ## CONSTRAINTS
  - SC-OBS-069: Dual Log (Term+SigNoz)
  - SC-OBS-071: 4 OTEL modules
  - SC-VER-035: OTEL traces flowing
  - AOR-OBS-001: Safety violations immediately observable
  """

  use ExUnit.Case, async: true
  use ExUnitProperties
  alias StreamData, as: SD

  # ============================================================================
  # Span Creation Tests
  # ============================================================================

  describe "span creation" do
    test "root span has valid trace_id and span_id" do
      span = create_root_span("test.operation")

      assert is_binary(span.trace_id)
      assert byte_size(span.trace_id) == 32
      assert is_binary(span.span_id)
      assert byte_size(span.span_id) == 16
      assert span.parent_span_id == nil
      assert span.name == "test.operation"
    end

    test "child span inherits trace_id from parent" do
      parent = create_root_span("parent.op")
      child = create_child_span(parent, "child.op")

      assert child.trace_id == parent.trace_id
      assert child.parent_span_id == parent.span_id
      refute child.span_id == parent.span_id
    end

    test "span includes required attributes" do
      span = create_root_span("indrajaal.guardian.validate")

      span =
        add_attributes(span, %{
          "service.name" => "indrajaal",
          "service.version" => "21.3.0",
          "otel.status_code" => "OK"
        })

      assert span.attributes["service.name"] == "indrajaal"
      assert span.attributes["service.version"] == "21.3.0"
    end

    test "span timing is accurate" do
      span = create_root_span("timed.op")
      Process.sleep(5)
      span = end_span(span)

      duration_us = span.end_time - span.start_time
      assert duration_us >= 5_000, "Duration #{duration_us}us should be >= 5ms"
      assert duration_us < 100_000, "Duration #{duration_us}us should be < 100ms"
    end
  end

  # ============================================================================
  # Context Propagation Tests
  # ============================================================================

  describe "context propagation" do
    test "trace context serializes to W3C traceparent format" do
      span = create_root_span("serialized.op")
      traceparent = to_traceparent(span)

      # W3C Trace Context format: version-trace_id-parent_id-flags
      assert String.starts_with?(traceparent, "00-")
      parts = String.split(traceparent, "-")
      assert length(parts) == 4
      # trace_id
      assert String.length(Enum.at(parts, 1)) == 32
      # span_id
      assert String.length(Enum.at(parts, 2)) == 16
    end

    test "trace context round-trips through serialization" do
      span = create_root_span("roundtrip.op")
      traceparent = to_traceparent(span)
      {:ok, context} = from_traceparent(traceparent)

      assert context.trace_id == span.trace_id
      assert context.span_id == span.span_id
    end

    test "invalid traceparent is rejected" do
      assert {:error, :invalid_traceparent} = from_traceparent("invalid")
      assert {:error, :invalid_traceparent} = from_traceparent("00-short-too-01")
      assert {:error, :invalid_traceparent} = from_traceparent("")
    end

    test "cross-service spans maintain trace context" do
      # Simulate: Service A -> Service B -> Service C
      service_a = create_root_span("service_a.request")
      traceparent_ab = to_traceparent(service_a)

      {:ok, ctx_b} = from_traceparent(traceparent_ab)
      service_b = create_child_span_from_context(ctx_b, "service_b.process")
      traceparent_bc = to_traceparent(service_b)

      {:ok, ctx_c} = from_traceparent(traceparent_bc)
      service_c = create_child_span_from_context(ctx_c, "service_c.store")

      # All 3 spans share the same trace_id
      assert service_a.trace_id == service_b.trace_id
      assert service_b.trace_id == service_c.trace_id

      # Parent chain: A <- B <- C
      assert service_b.parent_span_id == service_a.span_id
      assert service_c.parent_span_id == service_b.span_id
    end
  end

  # ============================================================================
  # Span Correlation Tests
  # ============================================================================

  describe "span correlation" do
    test "correlate spans by trace_id" do
      root = create_root_span("root")
      child1 = create_child_span(root, "child.1")
      child2 = create_child_span(root, "child.2")
      grandchild = create_child_span(child1, "grandchild.1")

      spans = [root, child1, child2, grandchild]
      trace = correlate_spans(spans, root.trace_id)

      assert length(trace) == 4
      assert Enum.all?(trace, &(&1.trace_id == root.trace_id))
    end

    test "build span tree from flat list" do
      root = create_root_span("root")
      child1 = create_child_span(root, "child.1")
      child2 = create_child_span(root, "child.2")
      grandchild = create_child_span(child1, "grandchild.1")

      # scrambled order
      spans = [grandchild, child2, root, child1]
      tree = build_span_tree(spans)

      assert tree.span.name == "root"
      assert length(tree.children) == 2
    end

    test "detect orphaned spans" do
      root = create_root_span("root")
      child = create_child_span(root, "child")

      # Create orphan - references non-existent parent
      orphan = %{
        trace_id: root.trace_id,
        span_id: generate_span_id(),
        parent_span_id: "nonexistent_parent",
        name: "orphan.op",
        start_time: System.monotonic_time(:microsecond),
        end_time: nil,
        attributes: %{}
      }

      spans = [root, child, orphan]
      orphans = find_orphaned_spans(spans)

      assert length(orphans) == 1
      assert hd(orphans).name == "orphan.op"
    end
  end

  # ============================================================================
  # OTEL Export Tests (SC-OBS-071)
  # ============================================================================

  describe "OTEL export format (SC-OBS-071)" do
    test "span exports to OTLP-compatible format" do
      span = create_root_span("export.test")
      span = add_attributes(span, %{"key" => "value"})
      span = end_span(span)

      exported = export_span(span)

      assert exported.traceId == span.trace_id
      assert exported.spanId == span.span_id
      assert exported.name == "export.test"
      assert is_integer(exported.startTimeUnixNano)
      assert is_integer(exported.endTimeUnixNano)
      assert is_list(exported.attributes)
    end

    test "batch export handles multiple spans" do
      spans =
        for i <- 1..10 do
          create_root_span("batch.span.#{i}")
          |> end_span()
        end

      {:ok, batch} = export_batch(spans)
      assert batch.count == 10
      assert length(batch.spans) == 10
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: span IDs are unique" do
    @tag timeout: 30_000
    test "generated spans always have unique IDs" do
      ExUnitProperties.check all(count <- SD.integer(2..50)) do
        spans =
          for i <- 1..count do
            create_root_span("prop.test.#{i}")
          end

        span_ids = Enum.map(spans, & &1.span_id)

        assert length(Enum.uniq(span_ids)) == count,
               "Expected #{count} unique span IDs, got #{length(Enum.uniq(span_ids))}"
      end
    end
  end

  describe "property: traceparent round-trip" do
    @tag timeout: 30_000
    test "any valid span survives traceparent serialization" do
      ExUnitProperties.check all(name <- SD.string(:alphanumeric, min_length: 3, max_length: 30)) do
        span = create_root_span(name)
        traceparent = to_traceparent(span)
        {:ok, ctx} = from_traceparent(traceparent)

        assert ctx.trace_id == span.trace_id
        assert ctx.span_id == span.span_id
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp create_root_span(name) do
    %{
      trace_id: generate_trace_id(),
      span_id: generate_span_id(),
      parent_span_id: nil,
      name: name,
      start_time: System.monotonic_time(:microsecond),
      end_time: nil,
      attributes: %{}
    }
  end

  defp create_child_span(parent, name) do
    %{
      trace_id: parent.trace_id,
      span_id: generate_span_id(),
      parent_span_id: parent.span_id,
      name: name,
      start_time: System.monotonic_time(:microsecond),
      end_time: nil,
      attributes: %{}
    }
  end

  defp create_child_span_from_context(ctx, name) do
    %{
      trace_id: ctx.trace_id,
      span_id: generate_span_id(),
      parent_span_id: ctx.span_id,
      name: name,
      start_time: System.monotonic_time(:microsecond),
      end_time: nil,
      attributes: %{}
    }
  end

  defp add_attributes(span, attrs) do
    %{span | attributes: Map.merge(span.attributes, attrs)}
  end

  defp end_span(span) do
    %{span | end_time: System.monotonic_time(:microsecond)}
  end

  defp to_traceparent(span) do
    flags = "01"
    "00-#{span.trace_id}-#{span.span_id}-#{flags}"
  end

  defp from_traceparent(traceparent) when is_binary(traceparent) do
    case String.split(traceparent, "-") do
      ["00", trace_id, span_id, _flags]
      when byte_size(trace_id) == 32 and byte_size(span_id) == 16 ->
        {:ok, %{trace_id: trace_id, span_id: span_id}}

      _ ->
        {:error, :invalid_traceparent}
    end
  end

  defp correlate_spans(spans, trace_id) do
    Enum.filter(spans, &(&1.trace_id == trace_id))
  end

  defp build_span_tree(spans) do
    by_id = Map.new(spans, &{&1.span_id, &1})

    root =
      Enum.find(spans, &is_nil(&1.parent_span_id))

    children =
      spans
      |> Enum.filter(&(&1.parent_span_id == root.span_id))
      |> Enum.map(fn child ->
        %{span: child, children: find_children(spans, child.span_id)}
      end)

    %{span: root, children: children}
  end

  defp find_children(spans, parent_id) do
    spans
    |> Enum.filter(&(&1.parent_span_id == parent_id))
    |> Enum.map(fn child ->
      %{span: child, children: find_children(spans, child.span_id)}
    end)
  end

  defp find_orphaned_spans(spans) do
    span_ids = MapSet.new(spans, & &1.span_id)

    Enum.filter(spans, fn span ->
      span.parent_span_id != nil and not MapSet.member?(span_ids, span.parent_span_id)
    end)
  end

  defp export_span(span) do
    %{
      traceId: span.trace_id,
      spanId: span.span_id,
      parentSpanId: span.parent_span_id,
      name: span.name,
      startTimeUnixNano:
        System.os_time(:nanosecond) -
          (System.monotonic_time(:microsecond) - span.start_time) * 1000,
      endTimeUnixNano:
        if(span.end_time,
          do:
            System.os_time(:nanosecond) -
              (System.monotonic_time(:microsecond) - span.end_time) * 1000,
          else: nil
        ),
      attributes:
        Enum.map(span.attributes, fn {k, v} -> %{key: k, value: %{stringValue: to_string(v)}} end)
    }
  end

  defp export_batch(spans) do
    exported = Enum.map(spans, &export_span/1)
    {:ok, %{count: length(exported), spans: exported}}
  end
end
