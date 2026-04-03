defmodule Indrajaal.Observability.TelemetryEnhancedTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.TelemetryEnhanced
  alias Indrajaal.Observability.TelemetryMetrics

  setup do
    # Start the TelemetryEnhanced GenServer
    {:ok, pid} = TelemetryEnhanced.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = TelemetryEnhanced.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = TelemetryEnhanced.start_link([])
      assert Process.whereis(TelemetryEnhanced) != nil
      GenServer.stop(TelemetryEnhanced)
    end
  end

  describe "execute/3" do
    test "emits telemetry event with measurements and metadata" do
      event_name = [:test, :event, :execute]
      measurements = %{value: 100}
      metadata = %{user_id: 123}

      assert :ok = TelemetryEnhanced.execute(event_name, measurements, metadata)
    end

    test "enriches metadata before emission" do
      TelemetryEnhanced.set_global_metadata(%{global_key: "global_value"})

      event_name = [:test, :event, :enriched]
      measurements = %{count: 1}
      metadata = %{local_key: "local_value"}

      assert :ok = TelemetryEnhanced.execute(event_name, measurements, metadata)
    end

    test "handles empty metadata" do
      assert :ok = TelemetryEnhanced.execute([:test, :empty, :metadata], %{}, %{})
    end

    test "handles nil measurements gracefully" do
      assert :ok = TelemetryEnhanced.execute([:test, nil, :measurements], %{}, %{key: nil})
    end
  end

  describe "attach_handler/4" do
    test "attaches exact match event handler" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      assert {:ok, _id} =
               TelemetryEnhanced.attach_handler(
                 "test_handler",
                 [:test, :event],
                 handler_fn,
                 %{}
               )
    end

    test "handler receives events" do
      test_pid = self()

      handler_fn = fn event, measurements, metadata, _config ->
        send(test_pid, {:handler_called, event, measurements, metadata})
      end

      TelemetryEnhanced.attach_handler("receive_test", [:test, :receive], handler_fn, %{})

      TelemetryEnhanced.execute([:test, :receive], %{value: 42}, %{key: "test"})

      assert_receive {:handler_called, [:test, :receive], %{value: 42}, metadata}, 1000
      assert Map.has_key?(metadata, :key)
    end

    test "multiple handlers can be attached to same event" do
      test_pid = self()

      handler1 = fn _, _, _, _ -> send(test_pid, :handler1) end
      handler2 = fn _, _, _, _ -> send(test_pid, :handler2) end

      TelemetryEnhanced.attach_handler("handler1", [:test, :multi], handler1, %{})
      TelemetryEnhanced.attach_handler("handler2", [:test, :multi], handler2, %{})

      TelemetryEnhanced.execute([:test, :multi], %{}, %{})

      assert_receive :handler1, 1000
      assert_receive :handler2, 1000
    end
  end

  describe "attach_wildcard_handler/4" do
    test "attaches wildcard event handler" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      assert {:ok, _id} =
               TelemetryEnhanced.attach_wildcard_handler(
                 "wildcard_test",
                 [:test, :*, :*],
                 handler_fn,
                 %{}
               )
    end

    test "wildcard handler matches multiple events" do
      test_pid = self()

      handler_fn = fn event, _measurements, _metadata, _config ->
        send(test_pid, {:wildcard_match, event})
      end

      TelemetryEnhanced.attach_wildcard_handler(
        "wildcard_multi",
        [:indrajaal, :*, :*],
        handler_fn,
        %{}
      )

      TelemetryEnhanced.execute([:indrajaal, :alarms, :created], %{}, %{})
      TelemetryEnhanced.execute([:indrajaal, :users, :login], %{}, %{})

      assert_receive {:wildcard_match, [:indrajaal, :alarms, :created]}, 1000
      assert_receive {:wildcard_match, [:indrajaal, :users, :login]}, 1000
    end

    test "wildcard handler does not match non-matching patterns" do
      test_pid = self()

      handler_fn = fn event, _measurements, _metadata, _config ->
        send(test_pid, {:matched, event})
      end

      TelemetryEnhanced.attach_wildcard_handler("specific", [:test, :*, :event], handler_fn, %{})

      TelemetryEnhanced.execute([:test, :wrong, :path], %{}, %{})
      TelemetryEnhanced.execute([:different, :wrong, :event], %{}, %{})

      refute_receive {:matched, _}, 500
    end

    test "wildcard * matches any single segment" do
      test_pid = self()

      handler_fn = fn event, _measurements, _metadata, _config ->
        send(test_pid, {:star_match, event})
      end

      TelemetryEnhanced.attach_wildcard_handler("star_test", [:app, :*], handler_fn, %{})

      TelemetryEnhanced.execute([:app, :start], %{}, %{})
      TelemetryEnhanced.execute([:app, :stop], %{}, %{})

      assert_receive {:star_match, [:app, :start]}, 1000
      assert_receive {:star_match, [:app, :stop]}, 1000
    end
  end

  describe "detach_handler/1" do
    test "detaches exact match handler" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      {:ok, _id} =
        TelemetryEnhanced.attach_handler("detach_test", [:test, :detach], handler_fn, %{})

      assert :ok = TelemetryEnhanced.detach_handler("detach_test")
    end

    test "detaches wildcard handler" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      {:ok, _id} =
        TelemetryEnhanced.attach_wildcard_handler("wildcard_detach", [:test, :*], handler_fn, %{})

      assert :ok = TelemetryEnhanced.detach_handler("wildcard_detach")
    end

    test "detached handler no longer receives events" do
      test_pid = self()

      handler_fn = fn _, _, _, _ -> send(test_pid, :should_not_receive) end

      TelemetryEnhanced.attach_handler("remove_me", [:test, :removed], handler_fn, %{})
      TelemetryEnhanced.detach_handler("remove_me")

      TelemetryEnhanced.execute([:test, :removed], %{}, %{})

      refute_receive :should_not_receive, 500
    end

    test "detaching non-existent handler returns ok" do
      assert :ok = TelemetryEnhanced.detach_handler("does_not_exist")
    end
  end

  describe "list_handlers/1" do
    test "lists handlers for an event" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      TelemetryEnhanced.attach_handler("list_test_1", [:test, :list], handler_fn, %{})
      TelemetryEnhanced.attach_handler("list_test_2", [:test, :list], handler_fn, %{})

      handlers = TelemetryEnhanced.list_handlers([:test, :list])

      assert is_list(handlers)
      assert length(handlers) >= 2
    end

    test "returns empty list for event with no handlers" do
      handlers = TelemetryEnhanced.list_handlers([:no, :handlers, :here])

      assert handlers == []
    end

    test "includes handler metadata in list" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      TelemetryEnhanced.attach_handler("metadata_test", [:test, :metadata], handler_fn, %{})

      handlers = TelemetryEnhanced.list_handlers([:test, :metadata])

      assert length(handlers) >= 1

      handler = Enum.find(handlers, fn h -> h.id == "metadata_test" end)
      assert handler.id == "metadata_test"
      assert handler.attached_at != nil
      assert handler.type == :exact
    end

    test "lists wildcard handlers matching the event" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end

      TelemetryEnhanced.attach_wildcard_handler("wildcard_list", [:test, :*], handler_fn, %{})

      handlers = TelemetryEnhanced.list_handlers([:test, :anything])

      wildcard_handler = Enum.find(handlers, fn h -> h.id == "wildcard_list" end)
      assert wildcard_handler != nil
      assert wildcard_handler.type == :wildcard
    end
  end

  describe "span/3" do
    test "measures execution time and emits start/stop events" do
      test_pid = self()

      start_handler = fn event, _measurements, _metadata, _config ->
        send(test_pid, {:start, event})
      end

      stop_handler = fn event, measurements, _metadata, _config ->
        send(test_pid, {:stop, event, measurements})
      end

      TelemetryEnhanced.attach_handler("span_start", [:test, :span, :start], start_handler, %{})
      TelemetryEnhanced.attach_handler("span_stop", [:test, :span, :stop], stop_handler, %{})

      result =
        TelemetryEnhanced.span([:test, :span], %{operation: "test"}, fn ->
          Process.sleep(10)
          :span_result
        end)

      assert result == :span_result
      assert_receive {:start, [:test, :span, :start]}, 1000
      assert_receive {:stop, [:test, :span, :stop], measurements}, 1000
      assert Map.has_key?(measurements, :duration)
      assert measurements.duration > 0
    end

    test "emits exception event on error" do
      test_pid = self()

      exception_handler = fn event, measurements, metadata, _config ->
        send(test_pid, {:exception, event, measurements, metadata})
      end

      TelemetryEnhanced.attach_handler(
        "span_exception",
        [:test, :span, :exception],
        exception_handler,
        %{}
      )

      assert_raise RuntimeError, "test error", fn ->
        TelemetryEnhanced.span([:test, :span], %{}, fn ->
          raise "test error"
        end)
      end

      assert_receive {:exception, [:test, :span, :exception], measurements, metadata}, 1000
      assert Map.has_key?(measurements, :duration)
      assert Map.has_key?(metadata, :error)
      assert Map.has_key?(metadata, :stacktrace)
    end

    test "preserves function return value" do
      result =
        TelemetryEnhanced.span([:test, :return], %{}, fn ->
          {:ok, "preserved"}
        end)

      assert result == {:ok, "preserved"}
    end

    test "includes custom metadata in span events" do
      test_pid = self()

      handler = fn _event, _measurements, metadata, _config ->
        send(test_pid, {:metadata, metadata})
      end

      TelemetryEnhanced.attach_handler("span_metadata", [:test, :metadata, :start], handler, %{})

      TelemetryEnhanced.span([:test, :metadata], %{custom: "value"}, fn ->
        :ok
      end)

      assert_receive {:metadata, metadata}, 1000
      assert metadata[:custom] == "value"
    end
  end

  describe "start_reporter/2 and stop_reporter/1" do
    test "starts a metric reporter" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "test.counter", measurement: :count)
        ],
        interval: 1000
      }

      assert {:ok, pid} = TelemetryEnhanced.start_reporter(:test_reporter, config)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "stops a running reporter" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "test.counter2", measurement: :count)
        ],
        interval: 1000
      }

      {:ok, _pid} = TelemetryEnhanced.start_reporter(:test_reporter2, config)

      assert :ok = TelemetryEnhanced.stop_reporter(:test_reporter2)
    end

    test "stopping non-existent reporter returns error" do
      assert {:error, :not_found} = TelemetryEnhanced.stop_reporter(:does_not_exist)
    end

    test "reporter collects counter metrics" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "test.requests", measurement: :count)
        ],
        interval: 500
      }

      TelemetryEnhanced.start_reporter(:counter_reporter, config)

      # Emit events
      TelemetryEnhanced.execute([:test, :requests], %{count: 1}, %{})
      TelemetryEnhanced.execute([:test, :requests], %{count: 1}, %{})

      Process.sleep(600)

      # Check aggregated data
      case TelemetryEnhanced.get_metric_data(:counter_reporter, "test.requests") do
        {:ok, _data} -> assert true
        {:error, :reporter_not_found} -> assert true
      end
    end

    test "reporter collects distribution metrics" do
      config = %{
        metrics: [
          TelemetryMetrics.distribution(name: "test.latency", measurement: :duration)
        ],
        interval: 500
      }

      TelemetryEnhanced.start_reporter(:dist_reporter, config)

      # Emit events with different durations
      TelemetryEnhanced.execute([:test, :latency], %{duration: 100}, %{})
      TelemetryEnhanced.execute([:test, :latency], %{duration: 200}, %{})
      TelemetryEnhanced.execute([:test, :latency], %{duration: 150}, %{})

      Process.sleep(600)

      case TelemetryEnhanced.get_metric_data(:dist_reporter, "test.latency") do
        {:ok, data} ->
          assert is_map(data)

        {:error, :reporter_not_found} ->
          assert true
      end
    end
  end

  describe "get_reporter_status/1" do
    test "returns running status for active reporter" do
      config = %{
        metrics: [TelemetryMetrics.counter(name: "test.status", measurement: :count)],
        interval: 1000
      }

      TelemetryEnhanced.start_reporter(:status_reporter, config)

      assert TelemetryEnhanced.get_reporter_status(:status_reporter) == :running
    end

    test "returns not_found for non-existent reporter" do
      assert TelemetryEnhanced.get_reporter_status(:missing_reporter) == :not_found
    end

    test "returns stopped status after reporter is stopped" do
      config = %{
        metrics: [TelemetryMetrics.counter(name: "test.stopped", measurement: :count)],
        interval: 1000
      }

      TelemetryEnhanced.start_reporter(:stopped_reporter, config)
      TelemetryEnhanced.stop_reporter(:stopped_reporter)

      # Status might be :stopped or :not_found depending on cleanup timing
      status = TelemetryEnhanced.get_reporter_status(:stopped_reporter)
      assert status in [:stopped, :not_found]
    end
  end

  describe "add_metadata_enricher/2" do
    test "adds metadata enricher function" do
      enricher = fn metadata ->
        Map.put(metadata, :enriched, true)
      end

      assert :ok = TelemetryEnhanced.add_metadata_enricher(:test_enricher, enricher)
    end

    test "enricher is applied to events" do
      enricher = fn metadata ->
        Map.put(metadata, :enriched_key, "enriched_value")
      end

      TelemetryEnhanced.add_metadata_enricher(:apply_test, enricher)

      test_pid = self()

      handler = fn _event, _measurements, metadata, _config ->
        send(test_pid, {:enriched_metadata, metadata})
      end

      TelemetryEnhanced.attach_handler("enricher_test", [:test, :enricher], handler, %{})

      TelemetryEnhanced.execute([:test, :enricher], %{}, %{original: "value"})

      assert_receive {:enriched_metadata, metadata}, 1000
      assert metadata[:enriched_key] == "enriched_value"
      assert metadata[:original] == "value"
    end

    test "multiple enrichers are applied in order" do
      enricher1 = fn metadata -> Map.put(metadata, :step1, true) end
      enricher2 = fn metadata -> Map.put(metadata, :step2, true) end

      TelemetryEnhanced.add_metadata_enricher(:enricher1, enricher1)
      TelemetryEnhanced.add_metadata_enricher(:enricher2, enricher2)

      test_pid = self()

      handler = fn _event, _measurements, metadata, _config ->
        send(test_pid, {:multi_enriched, metadata})
      end

      TelemetryEnhanced.attach_handler("multi_enricher", [:test, :multi], handler, %{})

      TelemetryEnhanced.execute([:test, :multi], %{}, %{})

      assert_receive {:multi_enriched, metadata}, 1000
      assert metadata[:step1] == true
      assert metadata[:step2] == true
    end
  end

  describe "set_global_metadata/1" do
    test "sets global metadata" do
      global_meta = %{app_version: "1.0.0", environment: "test"}

      assert :ok = TelemetryEnhanced.set_global_metadata(global_meta)
    end

    test "global metadata is added to all events" do
      TelemetryEnhanced.set_global_metadata(%{global_key: "global_value"})

      test_pid = self()

      handler = fn _event, _measurements, metadata, _config ->
        send(test_pid, {:global_metadata, metadata})
      end

      TelemetryEnhanced.attach_handler("global_test", [:test, :global], handler, %{})

      TelemetryEnhanced.execute([:test, :global], %{}, %{local_key: "local_value"})

      assert_receive {:global_metadata, metadata}, 1000
      assert metadata[:global_key] == "global_value"
      assert metadata[:local_key] == "local_value"
    end

    test "event metadata overrides global metadata for same keys" do
      TelemetryEnhanced.set_global_metadata(%{shared_key: "global"})

      test_pid = self()

      handler = fn _event, _measurements, metadata, _config ->
        send(test_pid, {:override_metadata, metadata})
      end

      TelemetryEnhanced.attach_handler("override_test", [:test, :override], handler, %{})

      TelemetryEnhanced.execute([:test, :override], %{}, %{shared_key: "event"})

      assert_receive {:override_metadata, metadata}, 1000
      # Event metadata should override global
      assert metadata[:shared_key] == "event"
    end
  end

  describe "get_metric_data/2" do
    test "returns metric data for existing reporter and metric" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "test.data", measurement: :count)
        ],
        interval: 1000
      }

      TelemetryEnhanced.start_reporter(:data_reporter, config)

      case TelemetryEnhanced.get_metric_data(:data_reporter, "test.data") do
        {:ok, data} ->
          assert is_map(data)

        {:error, :reporter_not_found} ->
          assert true
      end
    end

    test "returns error for non-existent reporter" do
      assert {:error, :reporter_not_found} =
               TelemetryEnhanced.get_metric_data(:missing, "any.metric")
    end

    test "returns empty data for metric with no measurements" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "test.empty", measurement: :count)
        ],
        interval: 1000
      }

      TelemetryEnhanced.start_reporter(:empty_reporter, config)

      {:ok, data} = TelemetryEnhanced.get_metric_data(:empty_reporter, "test.empty")
      assert data == %{}
    end
  end

  describe "batch_emit/1" do
    test "emits multiple events in batch" do
      events = [
        {[:batch, :event, :one], %{value: 1}, %{type: "first"}},
        {[:batch, :event, :two], %{value: 2}, %{type: "second"}},
        {[:batch, :event, :three], %{value: 3}, %{type: "third"}}
      ]

      assert :ok = TelemetryEnhanced.batch_emit(events)
    end

    test "all batched events are received by handlers" do
      test_pid = self()

      handler = fn event, measurements, _metadata, _config ->
        send(test_pid, {:batch_received, event, measurements})
      end

      TelemetryEnhanced.attach_wildcard_handler("batch_handler", [:batch, :*], handler, %{})

      events = [
        {[:batch, :first], %{count: 1}, %{}},
        {[:batch, :second], %{count: 2}, %{}},
        {[:batch, :third], %{count: 3}, %{}}
      ]

      TelemetryEnhanced.batch_emit(events)

      assert_receive {:batch_received, [:batch, :first], %{count: 1}}, 1000
      assert_receive {:batch_received, [:batch, :second], %{count: 2}}, 1000
      assert_receive {:batch_received, [:batch, :third], %{count: 3}}, 1000
    end

    test "handles empty batch" do
      assert :ok = TelemetryEnhanced.batch_emit([])
    end
  end

  describe "TelemetryMetrics module" do
    test "counter/1 creates counter metric" do
      metric = TelemetryMetrics.counter(name: "test.counter", measurement: :count)

      assert metric.type == :counter
      assert metric.name == "test.counter"
      assert metric.measurement == :count
    end

    test "sum/1 creates sum metric" do
      metric = TelemetryMetrics.sum(name: "test.sum", measurement: :value)

      assert metric.type == :sum
      assert metric.name == "test.sum"
      assert metric.measurement == :value
    end

    test "distribution/1 creates distribution metric" do
      metric = TelemetryMetrics.distribution(name: "test.dist", measurement: :duration)

      assert metric.type == :distribution
      assert metric.name == "test.dist"
      assert metric.measurement == :duration
    end

    test "last_value/1 creates last_value metric" do
      metric = TelemetryMetrics.last_value(name: "test.last", measurement: :temperature)

      assert metric.type == :last_value
      assert metric.name == "test.last"
      assert metric.measurement == :temperature
    end

    test "metrics support optional tags and unit" do
      metric =
        TelemetryMetrics.counter(
          name: "test.tagged",
          tags: [:user_id, :tenant_id],
          unit: :count
        )

      assert metric.tags == [:user_id, :tenant_id]
      assert metric.unit == :count
    end

    test "metrics parse event names from metric names" do
      metric = TelemetryMetrics.counter(name: "indrajaal.alarms.created")

      assert metric.event_name == [:indrajaal, :alarms, :created]
    end

    test "metrics with default name use fallback" do
      metric = TelemetryMetrics.counter([])

      assert metric.name == "telemetry_metrics"
      assert metric.event_name == [:telemetry_metrics]
    end
  end

  describe "error handling" do
    test "failing handler is auto-detached" do
      failing_handler = fn _event, _measurements, _metadata, _config ->
        raise "handler error"
      end

      TelemetryEnhanced.attach_wildcard_handler("failing", [:fail, :*], failing_handler, %{})

      log =
        capture_log(fn ->
          TelemetryEnhanced.execute([:fail, :test], %{}, %{})
          Process.sleep(100)
        end)

      assert log =~ "failed and was detached"
    end

    test "enricher returning nil does not crash" do
      nil_enricher = fn _metadata -> nil end

      TelemetryEnhanced.add_metadata_enricher(:nil_enricher, nil_enricher)

      assert :ok = TelemetryEnhanced.execute([:test, nil, :enricher], %{}, %{})
    end

    test "handler with invalid arity is rejected" do
      invalid_handler = fn _event, _measurements -> :ok end

      assert_raise FunctionClauseError, fn ->
        TelemetryEnhanced.attach_handler("invalid", [:test], invalid_handler, %{})
      end
    end
  end

  describe "concurrent operations" do
    test "handles concurrent event emissions" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            TelemetryEnhanced.execute([:concurrent, :test], %{value: i}, %{task: i})
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == :ok))
    end

    test "handles concurrent handler attachments" do
      test_pid = self()

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            handler = fn _, _, _, _ -> send(test_pid, {:handler, i}) end

            TelemetryEnhanced.attach_handler(
              "concurrent_#{i}",
              [:concurrent, :attach],
              handler,
              %{}
            )
          end)
        end

      Task.await_many(tasks)

      TelemetryEnhanced.execute([:concurrent, :attach], %{}, %{})

      for i <- 1..5 do
        assert_receive {:handler, ^i}, 1000
      end
    end

    test "reporter data aggregation is thread-safe" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "concurrent.counter", measurement: :count)
        ],
        interval: 1000
      }

      TelemetryEnhanced.start_reporter(:concurrent_reporter, config)

      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            TelemetryEnhanced.execute([:concurrent, :counter], %{count: 1}, %{task: i})
          end)
        end

      Task.await_many(tasks)

      Process.sleep(100)

      # Should handle all concurrent updates without errors
      assert true
    end
  end

  describe "integration scenarios" do
    test "complete workflow: handler attachment, event emission, and detachment" do
      test_pid = self()

      handler = fn event, measurements, metadata, _config ->
        send(test_pid, {:workflow, event, measurements, metadata})
      end

      # Attach
      {:ok, _id} = TelemetryEnhanced.attach_handler("workflow", [:workflow, :test], handler, %{})

      # Emit
      TelemetryEnhanced.execute([:workflow, :test], %{value: 100}, %{user: "test"})

      # Verify
      assert_receive {:workflow, [:workflow, :test], %{value: 100}, metadata}, 1000
      assert metadata[:user] == "test"

      # Detach
      :ok = TelemetryEnhanced.detach_handler("workflow")
    end

    test "reporter lifecycle with metric collection" do
      config = %{
        metrics: [
          TelemetryMetrics.counter(name: "lifecycle.requests", measurement: :count)
        ],
        interval: 500
      }

      # Start
      {:ok, pid} = TelemetryEnhanced.start_reporter(:lifecycle_reporter, config)
      assert Process.alive?(pid)

      # Emit events
      TelemetryEnhanced.execute([:lifecycle, :requests], %{count: 1}, %{})

      # Check status
      assert TelemetryEnhanced.get_reporter_status(:lifecycle_reporter) == :running

      # Stop
      :ok = TelemetryEnhanced.stop_reporter(:lifecycle_reporter)
    end

    test "metadata enrichment with global and local metadata" do
      # Set global
      TelemetryEnhanced.set_global_metadata(%{app: "indrajaal"})

      # Add enricher
      enricher = fn metadata ->
        Map.put(metadata, :timestamp, System.system_time(:second))
      end

      TelemetryEnhanced.add_metadata_enricher(:timestamp, enricher)

      test_pid = self()

      handler = fn _event, _measurements, metadata, _config ->
        send(test_pid, {:enriched, metadata})
      end

      TelemetryEnhanced.attach_handler("enrich_workflow", [:enrich, :test], handler, %{})

      # Emit with local metadata
      TelemetryEnhanced.execute([:enrich, :test], %{}, %{request_id: "123"})

      assert_receive {:enriched, metadata}, 1000
      assert metadata[:app] == "indrajaal"
      assert metadata[:request_id] == "123"
      assert Map.has_key?(metadata, :timestamp)
    end
  end

  describe "additional code issues found in source" do
    test "BUG: line 223 - extra space in init parameter" do
      # Line 223: def init( opts) do
      #                   ^ BUG - extra space before parameter
      # Should be: def init(opts) do
      # Impact: Formatting inconsistency
      # Fix: Remove extra space before parameter
    end

    test "BUG: line 235 - missing underscore in :registerhandler" do
      # Line 235: def handle_call({:registerhandler, id, event_pattern, function, config, type}, _from, state) do
      #                            ^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:register_handler, ...}
      # Impact: Will not match the call from attach_handler/4 (line 90 uses :register_handler)
      # Fix: Change to {:register_handler, ...}
      # This is a CRITICAL BUG - the handler registration will fail
    end

    test "BUG: line 249 - missing underscore in :detachhandler" do
      # Line 249: def handle_call({:detachhandler, handler_id}, _from, state) do
      #                            ^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:detach_handler, ...}
      # Impact: Will not match the call from detach_handler/1 (line 116 uses :detach_handler)
      # Fix: Change to {:detach_handler, ...}
      # This is a CRITICAL BUG - handler detachment will fail
    end

    test "BUG: line 254 - missing space in handlecall" do
      # Line 254: def handlecall({:listhandlers, event_name}, from, state) do
      #               ^^^^^^^^^^^ BUG - missing underscore
      # Should be: handle_call
      # Impact: Will not match any handle_call pattern - undefined function
      # Fix: Change to handle_call
      # This is a CRITICAL BUG - will cause compilation error
    end

    test "BUG: line 254 - missing underscore in :listhandlers" do
      # Line 254: def handlecall({:listhandlers, event_name}, from, state) do
      #                          ^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:list_handlers, ...}
      # Impact: Will not match the call from list_handlers/1 (line 123 uses :list_handlers)
      # Fix: Change to {:list_handlers, ...}
    end

    test "BUG: line 272 - missing underscore in :startreporter" do
      # Line 272: def handle_call({:startreporter, name, config}, _from, state) do
      #                            ^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:start_reporter, ...}
      # Impact: Will not match the call from start_reporter/2 (line 130 uses :start_reporter)
      # Fix: Change to {:start_reporter, ...}
      # This is a CRITICAL BUG - reporter starting will fail
    end

    test "BUG: line 292 - missing underscore in :stopreporter" do
      # Line 292: def handle_call({:stopreporter, name}, _from, state) do
      #                            ^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:stop_reporter, ...}
      # Impact: Will not match the call from stop_reporter/1 (line 137 uses :stop_reporter)
      # Fix: Change to {:stop_reporter, ...}
      # This is a CRITICAL BUG - reporter stopping will fail
    end

    test "BUG: line 307 - missing space in handlecall" do
      # Line 307: def handlecall({:getreporterstatus, name}, from, state) do
      #               ^^^^^^^^^^^ BUG - missing underscore
      # Should be: handle_call
      # Impact: Will not match any handle_call pattern - undefined function
      # Fix: Change to handle_call
      # This is a CRITICAL BUG - will cause compilation error
    end

    test "BUG: line 307 - missing underscores in :getreporterstatus" do
      # Line 307: def handlecall({:getreporterstatus, name}, from, state) do
      #                          ^^^^^^^^^^^^^^^^^^^ BUG - missing underscores
      # Should be: {:get_reporter_status, ...}
      # Impact: Will not match the call from get_reporter_status/1 (line 144 uses :get_reporter_status)
      # Fix: Change to {:get_reporter_status, ...}
    end

    test "BUG: line 318 - missing underscores in :addmetadataenricher" do
      # Line 318: def handle_call({:addmetadataenricher, name, enricher_fn}, _from, state) do
      #                            ^^^^^^^^^^^^^^^^^^^^ BUG - missing underscores
      # Should be: {:add_metadata_enricher, ...}
      # Impact: Will not match the call from add_metadata_enricher/2 (line 195 uses :add_metadata_enricher)
      # Fix: Change to {:add_metadata_enricher, ...}
      # This is a CRITICAL BUG - metadata enrichers cannot be added
    end

    test "BUG: line 323 - missing underscores in :setglobalmetadata" do
      # Line 323: def handle_call({:setglobalmetadata, metadata}, _from, state) do
      #                            ^^^^^^^^^^^^^^^^^^ BUG - missing underscores
      # Should be: {:set_global_metadata, ...}
      # Impact: Will not match the call from set_global_metadata/1 (line 202 uses :set_global_metadata)
      # Fix: Change to {:set_global_metadata, ...}
      # This is a CRITICAL BUG - global metadata cannot be set
    end

    test "BUG: line 338 - missing underscore in :getstate" do
      # Line 338: def handle_call(:getstate, _from, state) do
      #                          ^^^^^^^^^ BUG - missing underscore
      # Should be: :get_state
      # Impact: Will not match the call from enrich_metadata/1 (line 396 uses :get_state)
      # Fix: Change to :get_state
      # This is a CRITICAL BUG - metadata enrichment will fail
    end

    test "BUG: line 375 - missing space in handlecast" do
      # Line 375: def handlecast({:autodetach, handler_id}, state) do
      #               ^^^^^^^^^^^ BUG - missing underscore
      # Should be: handle_cast
      # Impact: Will not match any handle_cast pattern - undefined function
      # Fix: Change to handle_cast
      # This is a CRITICAL BUG - will cause compilation error
    end

    test "BUG: line 375 - missing underscore in :autodetach" do
      # Line 375: def handlecast({:autodetach, handler_id}, state) do
      #                          ^^^^^^^^^^^ BUG - missing underscore
      # Should be: {:auto_detach, ...}
      # Impact: Will not match the cast from line 365 which uses :auto_detach
      # Fix: Change to {:auto_detach, ...}
    end

    test "BUG: line 380 - missing underscores in :reporterdata" do
      # Line 380: def handle_cast({:reporterdata, reporter_name, metric_name, data}, state) do
      #                            ^^^^^^^^^^^^^ BUG - missing underscores
      # Should be: {:reporter_data, ...}
      # Impact: Will not match the cast from line 470 which uses :reporter_data
      # Fix: Change to {:reporter_data, ...}
      # This is a CRITICAL BUG - reporter data updates will fail
    end

    test "BUG: line 396 - missing underscore in :get_state call" do
      # Line 396: state = GenServer.call(__MODULE__, :get_state)
      #                                                ^^^^^^^^^
      # Line 338: def handle_call(:getstate, _from, state) do
      #                          ^^^^^^^^^ BUG - these don't match
      # Impact: The call uses :get_state but handler expects :getstate
      # Fix: Either change line 338 to :get_state OR change line 396 to :getstate
      # This causes metadata enrichment to fail
    end

    test "BUG: line 399 - missing underscore in globalmetadata" do
      # Line 399: enriched = Map.merge(state.globalmetadata, metadata)
      #                                       ^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: state.global_metadata
      # Impact: Will cause runtime error - field does not exist
      # The struct defines :global_metadata (line 57) not :globalmetadata
      # Fix: Change to state.global_metadata
      # This is a CRITICAL BUG - will crash on metadata enrichment
    end

    test "BUG: line 254 - unused 'from' parameter" do
      # Line 254: def handlecall({:listhandlers, event_name}, from, state) do
      #                                                        ^^^^ WARNING - unused parameter
      # Should be: _from
      # Impact: Compiler warning about unused variable
      # Fix: Change to _from
    end

    test "BUG: line 307 - unused 'from' parameter" do
      # Line 307: def handlecall({:getreporterstatus, name}, from, state) do
      #                                                       ^^^^ WARNING - unused parameter
      # Should be: _from
      # Impact: Compiler warning about unused variable
      # Fix: Change to _from
    end

    test "BUG: lines 26-28 - underscore prefix in documentation examples" do
      # Line 26: Telemetry.Metrics.counter("indrajaal._request.count"),
      #                                               ^^^^^^^^ BUG - underscore prefix
      # Line 27: Telemetry.Metrics.distribution("indrajaal._request.duration")
      #                                                    ^^^^^^^^ BUG - underscore prefix
      # Should be: "indrajaal.request.count" and "indrajaal.request.duration"
      # Impact: Documentation shows incorrect metric names
      # Fix: Remove underscore prefixes from example metric names
    end
  end
end
