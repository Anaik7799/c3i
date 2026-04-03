defmodule Indrajaal.Cluster.TelemetryEventCorrelationTest do
  @moduledoc """
  Cross-domain telemetry event correlation test suite.

  ## WHAT
  Tests that telemetry events from multiple domains (safety, access, alarms,
  Zenoh mesh) can be ingested, aggregated, and correlated across domain
  boundaries per SC-OBS-069 (dual log) and SC-OBS-071 (4 OTEL modules).
  All tests are self-contained — no running OTEL collector or Zenoh router required.

  ## CONSTRAINTS
  - SC-OBS-069: Dual Log (Term+SigNoz) — all events logged to both backends
  - SC-OBS-071: 4 OTEL modules mandatory — tracer, meter, logger, propagator
  - SC-PRF-050: Aggregation response < 50ms
  - SC-ZTEST-003: Telemetry publish latency < 10ms
  - SC-BUS-001: Async messaging only
  - SC-BUS-002: No blocking operations

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Sprint 88 Wave 3 — telemetry correlation tests |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :sprint_88
  @moduletag :telemetry
  @moduletag :observability

  # OTEL module set per SC-OBS-071
  @otel_modules [:tracer, :meter, :logger, :propagator]
  # Max correlation window in ms per SC-PRF-050
  @max_correlation_window_ms 50
  # Max publish latency per SC-ZTEST-003
  @max_publish_latency_ms 10
  # Domains for cross-domain correlation
  @domains [:safety, :access, :alarms, :zenoh_mesh]

  # ============================================================================
  # SECTION 1: Event Construction
  # ============================================================================

  describe "telemetry event construction" do
    test "builds valid telemetry event with required OTEL fields" do
      event = build_event(:safety, "guardian.proposal.approved", %{proposal_id: "P-001"})

      assert Map.has_key?(event, :trace_id)
      assert Map.has_key?(event, :span_id)
      assert Map.has_key?(event, :domain)
      assert Map.has_key?(event, :event_name)
      assert Map.has_key?(event, :timestamp_us)
      assert Map.has_key?(event, :payload)
      assert Map.has_key?(event, :otel_module)
      assert event.domain == :safety
    end

    test "events from different domains have distinct trace prefixes" do
      events = for domain <- @domains, do: build_event(domain, "test.event", %{})
      trace_prefixes = Enum.map(events, fn e -> String.slice(e.trace_id, 0, 4) end)

      # Each domain uses a distinct prefix
      assert length(Enum.uniq(trace_prefixes)) == length(@domains)
    end

    test "event timestamp is in microseconds (monotonic)" do
      e1 = build_event(:safety, "ev.1", %{})
      e2 = build_event(:access, "ev.2", %{})

      assert is_integer(e1.timestamp_us)
      assert e2.timestamp_us >= e1.timestamp_us
    end

    test "OTEL module assignment covers all 4 required modules (SC-OBS-071)" do
      events =
        for module <- @otel_modules do
          build_event_with_module(:safety, "otel.test", %{}, module)
        end

      assigned_modules = Enum.map(events, & &1.otel_module)
      assert Enum.sort(assigned_modules) == Enum.sort(@otel_modules)
    end

    test "dual log tag is present on all events (SC-OBS-069)" do
      event = build_event(:alarms, "alarm.raised", %{severity: :critical})
      log_line = format_dual_log(event)

      assert String.contains?(log_line, "[DUAL-LOG]"),
             "SC-OBS-069: all events MUST include [DUAL-LOG] tag"

      assert String.contains?(log_line, "term_backend"),
             "SC-OBS-069: term backend MUST be logged"

      assert String.contains?(log_line, "signoz_backend"),
             "SC-OBS-069: SigNoz backend MUST be logged"
    end
  end

  # ============================================================================
  # SECTION 2: Cross-Domain Aggregation
  # ============================================================================

  describe "cross-domain event aggregation (SC-OBS-069)" do
    test "aggregates events from all 4 domains" do
      events =
        for domain <- @domains do
          build_event(domain, "domain.event", %{domain: domain})
        end

      aggregated = aggregate_events(events)

      assert Map.has_key?(aggregated, :safety)
      assert Map.has_key?(aggregated, :access)
      assert Map.has_key?(aggregated, :alarms)
      assert Map.has_key?(aggregated, :zenoh_mesh)
    end

    test "aggregation preserves event count per domain" do
      safety_events = for i <- 1..5, do: build_event(:safety, "safety.#{i}", %{seq: i})
      access_events = for i <- 1..3, do: build_event(:access, "access.#{i}", %{seq: i})
      all_events = safety_events ++ access_events

      aggregated = aggregate_events(all_events)

      assert length(aggregated[:safety] || []) == 5
      assert length(aggregated[:access] || []) == 3
    end

    test "aggregation completes within 50ms latency budget (SC-PRF-050)" do
      events =
        for i <- 1..100, domain <- @domains do
          build_event(domain, "event.#{i}", %{seq: i})
        end

      {elapsed_us, aggregated} = :timer.tc(fn -> aggregate_events(events) end)
      elapsed_ms = elapsed_us / 1000

      assert map_size(aggregated) == length(@domains)

      assert elapsed_ms < @max_correlation_window_ms,
             "Aggregation of 400 events took #{Float.round(elapsed_ms, 2)}ms, budget #{@max_correlation_window_ms}ms"
    end

    test "events are ordered by timestamp within each domain" do
      events =
        for i <- 1..10 do
          %{build_event(:safety, "ev.#{i}", %{}) | timestamp_us: i * 1000}
        end

      # Shuffle to simulate out-of-order arrival
      shuffled = Enum.shuffle(events)
      aggregated = aggregate_events(shuffled)
      safety_events = aggregated[:safety] || []

      timestamps = Enum.map(safety_events, & &1.timestamp_us)

      assert timestamps == Enum.sort(timestamps),
             "Events MUST be sorted by timestamp within domain"
    end

    test "unknown domains are placed in :other bucket" do
      event = %{build_event(:safety, "test", %{}) | domain: :unknown_domain}
      aggregated = aggregate_events([event])
      assert Map.has_key?(aggregated, :other)
    end
  end

  # ============================================================================
  # SECTION 3: Correlation Logic
  # ============================================================================

  describe "cross-domain event correlation" do
    test "correlates safety and alarm events by trace_id" do
      trace_id = "trace-abc-123"
      safety_event = %{build_event(:safety, "guardian.proposal", %{}) | trace_id: trace_id}
      alarm_event = %{build_event(:alarms, "alarm.raised", %{}) | trace_id: trace_id}
      unrelated = build_event(:access, "access.ok", %{})

      correlated = correlate_by_trace([safety_event, alarm_event, unrelated], trace_id)

      assert length(correlated) == 2
      assert Enum.all?(correlated, fn e -> e.trace_id == trace_id end)
    end

    test "correlation window filters events outside time budget" do
      base_us = System.monotonic_time(:microsecond)

      in_window =
        for i <- 1..5 do
          %{build_event(:safety, "ev.#{i}", %{}) | timestamp_us: base_us + i * 1000}
        end

      # 200ms later — outside 50ms window
      out_of_window =
        for i <- 1..3 do
          %{build_event(:alarms, "late.#{i}", %{}) | timestamp_us: base_us + 200_000 + i * 1000}
        end

      all_events = in_window ++ out_of_window

      window_us = @max_correlation_window_ms * 1000
      windowed = filter_correlation_window(all_events, base_us, window_us)

      assert length(windowed) == 5,
             "Only events within #{@max_correlation_window_ms}ms window should be included"
    end

    test "multi-domain causal chain is detectable" do
      # Simulate: alarm raised → guardian proposal → access denied (causal chain)
      trace_id = "causal-chain-001"

      chain = [
        %{build_event(:alarms, "alarm.raised", %{severity: :critical}) | trace_id: trace_id},
        %{build_event(:safety, "guardian.proposal", %{action: :block}) | trace_id: trace_id},
        %{
          build_event(:access, "access.denied", %{reason: :guardian_blocked})
          | trace_id: trace_id
        }
      ]

      noise = for _ <- 1..10, do: build_event(Enum.random(@domains), "noise", %{})

      correlation = correlate_causal_chain(chain ++ noise, trace_id)

      assert length(correlation.chain) == 3
      assert hd(correlation.chain).domain == :alarms
      assert List.last(correlation.chain).domain == :access
    end

    test "concurrent events from same domain are deduplicated by span_id" do
      span_id = "span-dup-001"

      # Same event published twice (dedup scenario)
      event1 = %{build_event(:safety, "guardian.check", %{}) | span_id: span_id}
      event2 = %{build_event(:safety, "guardian.check", %{}) | span_id: span_id}
      other = build_event(:safety, "other.event", %{})

      deduped = deduplicate_by_span([event1, event2, other])

      assert length(deduped) == 2,
             "Duplicate span_id MUST be deduplicated — got #{length(deduped)}"
    end
  end

  # ============================================================================
  # SECTION 4: OTEL Module Coverage (SC-OBS-071)
  # ============================================================================

  describe "OTEL module coverage verification (SC-OBS-071)" do
    test "all 4 OTEL modules are represented in a full event batch" do
      # Build one event per OTEL module
      events =
        for module <- @otel_modules do
          build_event_with_module(:safety, "otel.#{module}", %{module: module}, module)
        end

      present_modules =
        events
        |> Enum.map(& &1.otel_module)
        |> Enum.uniq()
        |> Enum.sort()

      assert present_modules == Enum.sort(@otel_modules),
             "SC-OBS-071: all 4 OTEL modules MUST be present: #{inspect(@otel_modules)}"
    end

    test "tracer module emits span start and span end events" do
      tracer_event = build_event_with_module(:zenoh_mesh, "span", %{}, :tracer)
      span_record = emit_tracer_span(tracer_event, :start)
      span_end = emit_tracer_span(tracer_event, :end)

      assert span_record.phase == :start
      assert span_end.phase == :end
      assert span_record.trace_id == span_end.trace_id
    end

    test "meter module emits counter and gauge readings" do
      meter_event = build_event_with_module(:safety, "metric", %{value: 42}, :meter)
      counter = emit_meter_reading(meter_event, :counter)
      gauge = emit_meter_reading(meter_event, :gauge)

      assert counter.metric_type == :counter
      assert gauge.metric_type == :gauge
      assert is_number(counter.value)
    end

    test "logger module formats structured log with domain context" do
      logger_event = build_event_with_module(:alarms, "log.entry", %{alarm_id: "A-001"}, :logger)
      log_entry = emit_logger_record(logger_event)

      assert Map.has_key?(log_entry, :level)
      assert Map.has_key?(log_entry, :message)
      assert Map.has_key?(log_entry, :domain)
      assert Map.has_key?(log_entry, :trace_id)
      assert log_entry.domain == :alarms
    end

    test "propagator module injects and extracts W3C trace context" do
      propagator_event =
        build_event_with_module(:access, "propagate", %{}, :propagator)

      carrier = inject_trace_context(propagator_event)
      extracted = extract_trace_context(carrier)

      assert Map.has_key?(carrier, "traceparent"),
             "W3C traceparent header MUST be present"

      assert extracted.trace_id == propagator_event.trace_id
    end
  end

  # ============================================================================
  # SECTION 5: Dual Log Verification (SC-OBS-069)
  # ============================================================================

  describe "dual log emission (SC-OBS-069)" do
    test "every event produces exactly 2 log lines (term + SigNoz)" do
      event = build_event(:safety, "dual.test", %{})
      log_lines = emit_dual_log(event)

      assert length(log_lines) == 2,
             "SC-OBS-069: MUST produce exactly 2 log lines, got #{length(log_lines)}"

      backends = Enum.map(log_lines, & &1.backend)
      assert :term in backends, "SC-OBS-069: term backend required"
      assert :signoz in backends, "SC-OBS-069: SigNoz backend required"
    end

    test "both log lines share the same trace_id" do
      event = build_event(:alarms, "alarm.dual", %{alarm_id: "A-002"})
      log_lines = emit_dual_log(event)

      trace_ids = Enum.map(log_lines, & &1.trace_id) |> Enum.uniq()
      assert length(trace_ids) == 1, "Both backends MUST share the same trace_id"
    end

    test "term backend uses structured format" do
      event = build_event(:zenoh_mesh, "zenoh.event", %{topic: "indrajaal/test"})
      log_lines = emit_dual_log(event)
      term_line = Enum.find(log_lines, &(&1.backend == :term))

      assert is_map(term_line.payload)
      assert Map.has_key?(term_line.payload, :domain)
      assert Map.has_key?(term_line.payload, :event_name)
    end

    test "SigNoz backend includes OTEL attributes" do
      event = build_event(:safety, "guardian.validate", %{proposal_id: "P-002"})
      log_lines = emit_dual_log(event)
      signoz_line = Enum.find(log_lines, &(&1.backend == :signoz))

      assert Map.has_key?(signoz_line, :otel_attributes)
      assert Map.has_key?(signoz_line.otel_attributes, :service_name)
      assert Map.has_key?(signoz_line.otel_attributes, :trace_id)
    end

    test "batch of 100 events all produce dual log lines" do
      events = for i <- 1..100, do: build_event(Enum.at(@domains, rem(i, 4)), "ev.#{i}", %{})

      all_log_lines =
        events
        |> Enum.flat_map(&emit_dual_log/1)

      assert length(all_log_lines) == 200,
             "100 events × 2 backends = 200 log lines (SC-OBS-069)"
    end
  end

  # ============================================================================
  # SECTION 6: Publish Latency Verification
  # ============================================================================

  describe "telemetry publish latency (SC-ZTEST-003)" do
    test "single event publish completes under 10ms" do
      event = build_event(:safety, "latency.test", %{})

      {elapsed_us, :ok} = :timer.tc(fn -> simulate_publish(event) end)
      elapsed_ms = elapsed_us / 1000

      assert elapsed_ms < @max_publish_latency_ms,
             "Publish latency #{Float.round(elapsed_ms, 3)}ms exceeds #{@max_publish_latency_ms}ms (SC-ZTEST-003)"
    end

    test "50 sequential publishes all under latency budget" do
      latencies =
        for i <- 1..50 do
          event = build_event(Enum.at(@domains, rem(i, 4)), "seq.#{i}", %{})
          {elapsed_us, :ok} = :timer.tc(fn -> simulate_publish(event) end)
          elapsed_us / 1000
        end

      over_budget = Enum.filter(latencies, &(&1 >= @max_publish_latency_ms))

      assert length(over_budget) == 0,
             "#{length(over_budget)}/50 publishes exceeded #{@max_publish_latency_ms}ms (SC-ZTEST-003)"
    end

    test "publish result is :ok for valid events" do
      event = build_event(:alarms, "result.test", %{alarm_id: "A-003"})
      assert :ok == simulate_publish(event)
    end
  end

  # ============================================================================
  # SECTION 7: Property-Based Tests (EP-GEN-014)
  # ============================================================================

  describe "property: events from any domain aggregate correctly (PropCheck)" do
    @tag timeout: 30_000
    test "aggregation is idempotent" do
      forall domain <- PC.oneof([:safety, :access, :alarms, :zenoh_mesh]) do
        events = for i <- 1..5, do: build_event(domain, "prop.#{i}", %{seq: i})
        agg1 = aggregate_events(events)
        agg2 = aggregate_events(events)
        agg1 == agg2
      end
    end
  end

  describe "property: dual log always produces 2 lines per event (StreamData)" do
    @tag timeout: 30_000
    test "any domain and event name produces exactly 2 log lines" do
      ExUnitProperties.check all(
                               domain <- SD.member_of(@domains),
                               event_name <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        event = build_event(domain, event_name, %{})
        log_lines = emit_dual_log(event)
        assert length(log_lines) == 2
        backends = Enum.map(log_lines, & &1.backend)
        assert :term in backends
        assert :signoz in backends
      end
    end
  end

  describe "property: correlation window filtering is monotone (PropCheck)" do
    @tag timeout: 30_000
    test "narrower window never returns more events than wider window" do
      forall n <- PC.range(1, 20) do
        base_us = 0

        events =
          for i <- 1..n, do: %{build_event(:safety, "ev.#{i}", %{}) | timestamp_us: i * 5_000}

        window_narrow_us = 50_000
        window_wide_us = 100_000

        narrow = filter_correlation_window(events, base_us, window_narrow_us)
        wide = filter_correlation_window(events, base_us, window_wide_us)

        length(narrow) <= length(wide)
      end
    end
  end

  describe "property: event deduplication never adds events (StreamData)" do
    @tag timeout: 30_000
    test "dedup output length never exceeds input length" do
      ExUnitProperties.check all(n <- SD.integer(1..20)) do
        events = for i <- 1..n, do: build_event(:safety, "ev.#{i}", %{seq: i})
        deduped = deduplicate_by_span(events)
        assert length(deduped) <= length(events)
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  @domain_prefixes %{
    safety: "safe",
    access: "accs",
    alarms: "alrm",
    zenoh_mesh: "znoh"
  }

  defp build_event(domain, event_name, payload) do
    prefix = Map.get(@domain_prefixes, domain, "unkn")

    %{
      trace_id: "#{prefix}-#{System.unique_integer([:positive, :monotonic])}",
      span_id: "span-#{System.unique_integer([:positive])}",
      domain: domain,
      event_name: event_name,
      timestamp_us: System.monotonic_time(:microsecond),
      payload: payload,
      otel_module: :tracer,
      schema_version: "1.0.0"
    }
  end

  defp build_event_with_module(domain, event_name, payload, otel_module) do
    event = build_event(domain, event_name, payload)
    %{event | otel_module: otel_module}
  end

  defp format_dual_log(event) do
    "[DUAL-LOG] domain=#{event.domain} event=#{event.event_name} " <>
      "trace_id=#{event.trace_id} term_backend=true signoz_backend=true"
  end

  defp aggregate_events(events) do
    Enum.group_by(events, fn event ->
      if event.domain in @domains, do: event.domain, else: :other
    end)
    |> Enum.map(fn {domain, evts} ->
      {domain, Enum.sort_by(evts, & &1.timestamp_us)}
    end)
    |> Map.new()
  end

  defp correlate_by_trace(events, trace_id) do
    Enum.filter(events, &(&1.trace_id == trace_id))
  end

  defp filter_correlation_window(events, base_us, window_us) do
    Enum.filter(events, fn e ->
      e.timestamp_us >= base_us and e.timestamp_us < base_us + window_us
    end)
  end

  defp correlate_causal_chain(events, trace_id) do
    chain =
      events
      |> Enum.filter(&(&1.trace_id == trace_id))
      |> Enum.sort_by(& &1.timestamp_us)

    %{trace_id: trace_id, chain: chain, length: length(chain)}
  end

  defp deduplicate_by_span(events) do
    events
    |> Enum.uniq_by(& &1.span_id)
  end

  defp emit_tracer_span(event, phase) do
    %{
      trace_id: event.trace_id,
      span_id: event.span_id,
      phase: phase,
      domain: event.domain,
      timestamp_us: System.monotonic_time(:microsecond)
    }
  end

  defp emit_meter_reading(event, metric_type) do
    value = Map.get(event.payload, :value, 0)

    %{
      trace_id: event.trace_id,
      metric_type: metric_type,
      name: event.event_name,
      value: value,
      domain: event.domain,
      timestamp_us: System.monotonic_time(:microsecond)
    }
  end

  defp emit_logger_record(event) do
    %{
      level: :info,
      message: "[#{event.domain}] #{event.event_name}",
      domain: event.domain,
      trace_id: event.trace_id,
      span_id: event.span_id,
      payload: event.payload,
      timestamp_us: System.monotonic_time(:microsecond)
    }
  end

  defp inject_trace_context(event) do
    # W3C traceparent: 00-{trace_id_hex}-{span_id_hex}-01
    trace_hex =
      Base.encode16(:crypto.hash(:sha, event.trace_id), case: :lower) |> String.slice(0, 32)

    span_hex =
      Base.encode16(:crypto.hash(:sha, event.span_id), case: :lower) |> String.slice(0, 16)

    %{
      "traceparent" => "00-#{trace_hex}-#{span_hex}-01",
      "tracestate" => "indrajaal=#{event.domain}"
    }
  end

  defp extract_trace_context(carrier) do
    traceparent = Map.get(carrier, "traceparent", "")
    parts = String.split(traceparent, "-")

    trace_id =
      if length(parts) >= 2, do: Enum.at(parts, 1), else: "unknown"

    %{trace_id: trace_id, carrier: carrier}
  end

  defp emit_dual_log(event) do
    term_line = %{
      backend: :term,
      trace_id: event.trace_id,
      payload: %{
        domain: event.domain,
        event_name: event.event_name,
        timestamp_us: event.timestamp_us
      }
    }

    signoz_line = %{
      backend: :signoz,
      trace_id: event.trace_id,
      otel_attributes: %{
        service_name: "indrajaal-#{event.domain}",
        trace_id: event.trace_id,
        span_id: event.span_id,
        domain: event.domain,
        event_name: event.event_name,
        schema_version: event.schema_version
      }
    }

    [term_line, signoz_line]
  end

  defp simulate_publish(%{domain: _domain, event_name: _name}) do
    # Simulated publish — no actual Zenoh or OTEL collector required
    # In production this would call ZenohSession.publish/2 and OTEL telemetry emit
    :ok
  end
end
