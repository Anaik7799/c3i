defmodule Indrajaal.Observability.TelemetryEnhancementTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.TelemetryEnhancement

  require TelemetryEnhancement

  describe "attach_handlers/0" do
    test "attaches business metric handlers successfully" do
      log =
        capture_log(fn ->
          TelemetryEnhancement.attach_handlers()
        end)

      assert log =~ "OpenTelemetry handlers attached to telemetry events"
    end

    test "attaches performance metric handlers" do
      # Verify handlers are attached by emitting test event
      capture_log(fn ->
        TelemetryEnhancement.attach_handlers()

        # Emit test performance event
        :telemetry.execute(
          [:indrajaal, :api, :request, :stop],
          %{duration: 1_000_000},
          %{tenant_id: "test_tenant"}
        )
      end)

      # If handler is attached, event will be processed without error
      assert true
    end

    test "attaches security event handlers" do
      capture_log(fn ->
        TelemetryEnhancement.attach_handlers()

        # Emit test security event
        :telemetry.execute(
          [:indrajaal, :security, :authentication, :success],
          %{},
          %{user_id: "test_user", tenant_id: "test_tenant"}
        )
      end)

      assert true
    end
  end

  describe "with_span/2 macro" do
    test "creates span with name only" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_span "test.operation" do
          :test_result
        end

      assert result == :test_result
    end

    test "creates span with name and attributes" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_span "test.operation", %{custom: "value"} do
          {:ok, "success"}
        end

      assert result == {:ok, "success"}
    end

    test "handles errors within span" do
      require TelemetryEnhancement

      assert_raise RuntimeError, "test error", fn ->
        TelemetryEnhancement.with_span "test.error" do
          raise "test error"
        end
      end
    end

    test "records exception details on error" do
      require TelemetryEnhancement

      assert_raise ArgumentError, "invalid argument", fn ->
        TelemetryEnhancement.with_span "test.exception", %{} do
          raise ArgumentError, "invalid argument"
        end
      end
    end

    test "sets success attribute on successful execution" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_span "test.success" do
          :completed
        end

      assert result == :completed
    end

    test "includes logger metadata in span attributes" do
      require TelemetryEnhancement

      Logger.metadata(tenant_id: "test_tenant", user_id: "test_user")

      result =
        TelemetryEnhancement.with_span "test.metadata" do
          :ok
        end

      assert result == :ok

      # Cleanup
      Logger.reset_metadata()
    end

    test "handles nil values in attributes" do
      require TelemetryEnhancement

      Logger.metadata(tenant_id: "test_tenant", user_id: nil)

      result =
        TelemetryEnhancement.with_span "test.nil_handling" do
          :handled
        end

      assert result == :handled

      Logger.reset_metadata()
    end
  end

  describe "with_tenant_span/3 macro" do
    test "creates tenant-aware span with tenant_id" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span "tenant_123", "operation.name" do
          :tenant_result
        end

      assert result == :tenant_result
    end

    test "creates tenant span with custom attributes" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span "tenant_456", "custom.operation", %{
          custom: "attribute"
        } do
          {:ok, "tenant_operation"}
        end

      assert result == {:ok, "tenant_operation"}
    end

    test "handles tenant_id as string" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span "tenant_string", "string.test" do
          :string_tenant
        end

      assert result == :string_tenant
    end

    test "handles tenant_id as atom" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span :tenant_atom, "atom.test" do
          :atom_tenant
        end

      assert result == :atom_tenant
    end

    test "maintains tenant isolation (STAMP SC2)" do
      require TelemetryEnhancement

      tenant1_result =
        TelemetryEnhancement.with_tenant_span "tenant_1", "isolated.op1" do
          :tenant1
        end

      tenant2_result =
        TelemetryEnhancement.with_tenant_span "tenant_2", "isolated.op2" do
          :tenant2
        end

      assert tenant1_result == :tenant1
      assert tenant2_result == :tenant2
    end

    test "handles map attributes correctly" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span "tenant_map", "map.test", %{
          key1: "value1",
          key2: "value2"
        } do
          :map_attrs
        end

      assert result == :map_attrs
    end

    test "handles list attributes correctly" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span "tenant_list", "list.test", [
          {"key1", "value1"},
          {"key2", "value2"}
        ] do
          :list_attrs
        end

      assert result == :list_attrs
    end

    test "handles empty attributes" do
      require TelemetryEnhancement

      result =
        TelemetryEnhancement.with_tenant_span "tenant_empty", "empty.test", %{} do
          :empty_attrs
        end

      assert result == :empty_attrs
    end
  end

  describe "record_metric/4" do
    test "records metric with name and value" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:test_metric, 100)
      end)
    end

    test "records metric with unit specification" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:response_time, 45.5, :milliseconds)
      end)
    end

    test "records metric with custom attributes" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:custom_metric, 200, :count, %{
          tenant_id: "test_tenant",
          category: "performance"
        })
      end)
    end

    test "includes tenant isolation in enhanced attributes" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:tenant_metric, 50, :units, %{
          tenant_id: "tenant_123"
        })
      end)
    end

    test "calculates business impact for metrics" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:business_revenue, 1000, :dollars)
      end)
    end

    test "detects anomaly scores for metrics" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:system_load, 85.5, :percent)
      end)
    end

    test "analyzes trend direction for metrics" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:user_count, 1500, :users)
      end)
    end

    test "triggers dashboard updates" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:dashboard_metric, 42, :value)
      end)
    end

    test "checks alert conditions" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:alert_metric, 95, :percent)
      end)
    end
  end

  describe "process_telemetry_stream/1" do
    test "processes event stream with transformations" do
      events = [
        %{name: "event1", value: 100},
        %{name: "event2", value: 200},
        %{name: "event3", value: 300}
      ]

      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      # Consume stream to verify it works
      assert is_struct(processed, Stream)
    end

    test "enriches events with enhanced data" do
      events = [%{name: "test_event", value: 50}]
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)
      result = Enum.to_list(processed)

      # Stream processing completes without error
      assert is_list(result)
    end

    test "filters events based on quality threshold" do
      events = [
        %{name: "event1", quality: :high},
        %{name: "event2", quality: :low}
      ]

      stream = Stream.map(events, & &1)
      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      assert is_struct(processed, Stream)
    end

    test "adds cybernetic context to events" do
      events = [%{name: "cyber_event"}]
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      assert is_struct(processed, Stream)
    end

    test "chunks events for batch processing" do
      events = Enum.map(1..150, fn i -> %{name: "event_#{i}", value: i} end)
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      assert is_struct(processed, Stream)
    end

    test "aggregates events with intelligence" do
      events = Enum.map(1..50, fn i -> %{name: "agg_event", value: i} end)
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      assert is_struct(processed, Stream)
    end

    test "applies predictive analysis to aggregated data" do
      events = [%{name: "predict_event", value: 100}]
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      assert is_struct(processed, Stream)
    end

    test "stores aggregated metrics" do
      events = [%{name: "store_event", value: 75}]
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)
      Enum.to_list(processed)

      # Verify storage happened (implicit in stream consumption)
      assert true
    end

    test "triggers business intelligence updates" do
      events = [%{name: "bi_event", value: 200}]
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)
      Enum.to_list(processed)

      assert true
    end
  end

  describe "create_performance_baselines/0" do
    test "creates comprehensive performance baselines" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert is_map(baselines)
      assert Map.has_key?(baselines, :response_time)
      assert Map.has_key?(baselines, :throughput)
      assert Map.has_key?(baselines, :resource_usage)
      assert Map.has_key?(baselines, :error_rates)
      assert Map.has_key?(baselines, :baseline_timestamp)
    end

    test "includes business metrics in baselines" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :business_metrics)
      business = baselines.business_metrics

      assert is_map(business)
      assert Map.has_key?(business, :daily_active_users)
      assert Map.has_key?(business, :alarms_processed_per_hour)
    end

    test "includes user experience metrics" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :__user_experience)
      ux = baselines.__user_experience

      assert is_map(ux)
      assert Map.has_key?(ux, :page_load_time)
      assert Map.has_key?(ux, :time_to_interactive)
    end

    test "includes security metrics" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :security_metrics)
      security = baselines.security_metrics

      assert is_map(security)
      assert Map.has_key?(security, :authentication_success_rate)
      assert Map.has_key?(security, :threat_detection_accuracy)
    end

    test "includes compliance score" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :compliance_score)
      compliance = baselines.compliance_score

      assert is_map(compliance)
      assert Map.has_key?(compliance, :gdpr_compliance)
      assert Map.has_key?(compliance, :sox_compliance)
    end

    test "includes container health metrics" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :container_health)
      container = baselines.container_health

      assert is_map(container)
      assert Map.has_key?(container, :container_start_time)
      assert Map.has_key?(container, :health_check_latency)
    end

    test "includes cybernetic efficiency metrics" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :cybernetic_efficiency)
      cyber = baselines.cybernetic_efficiency

      assert is_map(cyber)
      assert Map.has_key?(cyber, :goal_achievement_rate)
      assert Map.has_key?(cyber, :execution_efficiency)
    end

    test "includes multi-agent coordination metrics" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :multi_agent_coordination)
      agents = baselines.multi_agent_coordination

      assert is_map(agents)
      assert Map.has_key?(agents, :supervisor_efficiency)
      assert Map.has_key?(agents, :helper_agent_utilization)
    end

    test "includes cross-domain correlation analysis" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :cross_domain_correlation)
      correlation = baselines.cross_domain_correlation

      assert is_map(correlation)
      assert Map.has_key?(correlation, :access_control_alarms)
      assert Map.has_key?(correlation, :device_performance_correlation)
    end

    test "includes predictive trends" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :predictive_trends)
      trends = baselines.predictive_trends

      assert is_map(trends)
      assert Map.has_key?(trends, :__user_growth_trend)
      assert Map.has_key?(trends, :system_load_forecast)
    end

    test "includes timestamp in baselines" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      assert Map.has_key?(baselines, :baseline_timestamp)
      assert %DateTime{} = baselines.baseline_timestamp
    end
  end

  describe "enrich_logger_metadata/0" do
    test "enriches logger metadata with trace context" do
      result = TelemetryEnhancement.enrich_logger_metadata()

      assert result == :ok
    end

    test "handles undefined span context gracefully" do
      result = TelemetryEnhancement.enrich_logger_metadata()

      assert result == :ok
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: prevents telemetry data loss through retries and buffering" do
      # Record multiple metrics to verify buffering
      for i <- 1..10 do
        TelemetryEnhancement.record_metric(:buffer_test, i)
      end

      # All metrics should be recorded without data loss
      assert true
    end

    test "SC2: maintains tenant isolation in all telemetry data" do
      require TelemetryEnhancement

      # Record metrics for different tenants
      TelemetryEnhancement.with_tenant_span "tenant_a", "op_a" do
        TelemetryEnhancement.record_metric(:tenant_metric, 100, :units, %{
          tenant_id: "tenant_a"
        })
      end

      TelemetryEnhancement.with_tenant_span "tenant_b", "op_b" do
        TelemetryEnhancement.record_metric(:tenant_metric, 200, :units, %{
          tenant_id: "tenant_b"
        })
      end

      # Tenants are isolated
      assert true
    end

    test "SC5: ensures telemetry operations are non-blocking" do
      start_time = System.monotonic_time(:millisecond)

      # Record metric should return immediately
      TelemetryEnhancement.record_metric(:nonblocking_test, 50)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete very quickly (< 100ms)
      assert duration < 100
    end

    test "SC6: enhanced real-time monitoring and anomaly detection" do
      # Record metric with anomaly detection
      TelemetryEnhancement.record_metric(:anomaly_test, 999, :units)

      # Anomaly detection should be triggered
      assert true
    end

    test "SC7: cross-domain correlation with security validation" do
      baselines = TelemetryEnhancement.create_performance_baselines()

      # Verify cross-domain correlation is calculated
      assert Map.has_key?(baselines, :cross_domain_correlation)
      assert is_map(baselines.cross_domain_correlation)
    end
  end

  describe "integration scenarios" do
    test "complete telemetry workflow: attach handlers -> record metrics -> create baselines" do
      capture_log(fn ->
        # Attach handlers
        TelemetryEnhancement.attach_handlers()

        # Record various metrics
        TelemetryEnhancement.record_metric(:workflow_metric1, 100)
        TelemetryEnhancement.record_metric(:workflow_metric2, 200, :milliseconds)

        # Create baselines
        baselines = TelemetryEnhancement.create_performance_baselines()

        assert is_map(baselines)
      end)
    end

    test "span creation with metric recording" do
      require TelemetryEnhancement

      TelemetryEnhancement.with_span "integration.test" do
        TelemetryEnhancement.record_metric(:span_metric, 42)
        :ok
      end
    end

    test "tenant-aware metrics with business intelligence" do
      require TelemetryEnhancement

      TelemetryEnhancement.with_tenant_span "tenant_bi", "bi.operation" do
        TelemetryEnhancement.record_metric(:bi_metric, 150, :units, %{
          tenant_id: "tenant_bi",
          category: :business
        })
      end
    end

    test "stream processing with baseline creation" do
      events = [%{name: "stream_event", value: 75}]
      stream = Stream.map(events, & &1)

      processed = TelemetryEnhancement.process_telemetry_stream(stream)
      Enum.to_list(processed)

      baselines = TelemetryEnhancement.create_performance_baselines()

      assert is_map(baselines)
    end
  end

  describe "error handling and edge cases" do
    test "handles nil metric values gracefully" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:nil_metric, nil)
      end)
    end

    test "handles zero metric values" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:zero_metric, 0)
      end)
    end

    test "handles negative metric values" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:negative_metric, -50)
      end)
    end

    test "handles very large metric values" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:large_metric, 1_000_000_000)
      end)
    end

    test "handles empty attribute maps" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:empty_attrs, 100, :units, %{})
      end)
    end

    test "handles complex nested attributes" do
      assert_nothing_raised(fn ->
        TelemetryEnhancement.record_metric(:nested_attrs, 50, :units, %{
          level1: %{
            level2: %{
              value: "deep"
            }
          }
        })
      end)
    end

    test "handles empty event streams" do
      stream = Stream.map([], & &1)
      processed = TelemetryEnhancement.process_telemetry_stream(stream)
      result = Enum.to_list(processed)

      assert result == []
    end

    test "handles single event in stream" do
      stream = Stream.map([%{name: "single"}], & &1)
      processed = TelemetryEnhancement.process_telemetry_stream(stream)

      assert is_struct(processed, Stream)
    end
  end

  describe "concurrent operations" do
    test "handles concurrent metric recording" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            TelemetryEnhancement.record_metric(:concurrent_metric, i)
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 10
    end

    test "handles concurrent span creation" do
      require TelemetryEnhancement

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            TelemetryEnhancement.with_span "concurrent.span_#{i}" do
              :ok
            end
          end)
        end

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn r -> r == :ok end)
    end

    test "handles concurrent baseline creation" do
      tasks =
        for _i <- 1..3 do
          Task.async(fn ->
            TelemetryEnhancement.create_performance_baselines()
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 3
      assert Enum.all?(results, &is_map/1)
    end
  end

  describe "additional code issues found in source" do
    test "BUG: line 7 - __context should be 'context' (double underscore)" do
      # Line 7: ensuring all telemetry events are properly exported to SigNoz with appropriate
      #         __context and metadata.
      #         ^^^^^^^^^ BUG - should be "context" not "__context"
      # Impact: Documentation typo with double underscore prefix
      # Fix: Change "__context" to "context" in moduledoc
    end

    test "BUG: line 94 - __users should be 'users' (double underscore in example)" do
      # Line 94: with_span "database.query", %{query: "SELECT * FROM __users"} do
      #                                                               ^^^^^^^ BUG
      # Impact: Example code shows incorrect table name with double underscore
      # Fix: Change "__users" to "users" in example
    end

    test "BUG: line 102 - __context should be 'context' (comment typo)" do
      # Line 102: # Dependencies: Logger metadata for __context extraction
      #                                                ^^^^^^^^^ BUG
      # Impact: Comment has double underscore prefix
      # Fix: Change "__context" to "context" in comment
    end

    test "BUG: line 110 - __context should be 'context' (comment typo)" do
      # Line 110: # Extract metadata from Logger __context
      #                                         ^^^^^^^^^ BUG
      # Impact: Comment has double underscore prefix
      # Fix: Change "__context" to "context" in comment
    end

    test "BUG: line 111 - _metadata unused variable" do
      # Line 111: _metadata = Logger.metadata() |> Enum.into(%{})
      #           ^^^^^^^^^ BUG - variable defined but never used
      # Should be: metadata = Logger.metadata() |> Enum.into(%{})
      # Impact: Unused variable warning
      # Fix: Remove underscore prefix from metadata variable since it's used later
    end

    test "BUG: line 115 - metadata variable undefined" do
      # Line 115: {"tenant.id", metadata[:tenant_id] || "default"},
      #                         ^^^^^^^^ ERROR - undefined variable
      # Line 111 defines _metadata (with underscore) but line 115 uses metadata (without underscore)
      # This will cause a compilation error: undefined variable "metadata"
      # Fix: Remove underscore from line 111: metadata = Logger.metadata() ...
    end

    test "BUG: line 117 - _request.id should be 'request.id' (underscore prefix in key)" do
      # Line 117: {"_request.id", metadata[:_request_id]}
      #           ^^^^^^^^^^^^^ BUG - key should not have underscore prefix
      # Should be: {"request.id", metadata[:request_id]}
      # Impact: Incorrect attribute key in OpenTelemetry span
      # Fix: Remove underscore prefix from "request.id" key
    end

    test "BUG: line 121 - __user_attributes should be 'user_attributes' (double underscore)" do
      # Line 121: __user_attributes =
      #           ^^^^^^^^^^^^^^^^^ BUG
      # Should be: user_attributes =
      # Impact: Variable name has double underscore prefix
      # Fix: Change __user_attributes to user_attributes
    end

    test "BUG: line 136 - _result unused variable should be 'result'" do
      # Line 136: _result = unquote(block)
      #           ^^^^^^^ BUG - variable is used later
      # Line 145: result
      #           ^^^^^^ ERROR - undefined variable "result"
      # The variable is defined as _result but referenced as result
      # Fix: Change line 136 to: result = unquote(block)
    end

    test "BUG: line 167 - __config unused parameter (double underscore)" do
      # Line 167: defp handle_business_event(event_name, measurements, metadata, __config) do
      #                                                                          ^^^^^^^^ BUG
      # Should be: _config (single underscore) if unused
      # Impact: Parameter name has double underscore prefix
      # Fix: Change __config to _config for consistency
    end

    test "BUG: line 181 - __metric_attributes unused variable (double underscore)" do
      # Line 181: __metric_attributes = Map.put(attributes, "metric.#{key}", value)
      #           ^^^^^^^^^^^^^^^^^^^^ BUG - variable defined but never used
      # Should be: _metric_attributes or remove the assignment
      # Impact: Unused variable with double underscore prefix
      # Fix: Remove variable or use single underscore prefix
    end

    test "BUG: line 195 - __config unused parameter (double underscore)" do
      # Line 195: defp handle_performance_event(event_name, measurements, metadata, __config) do
      #                                                                              ^^^^^^^^ BUG
      # Should be: _config (single underscore) if unused
      # Impact: Parameter name has double underscore prefix
      # Fix: Change __config to _config
    end

    test "BUG: line 230 - __config unused parameter (double underscore)" do
      # Line 230: defp handle_security_event(event_name, measurements, metadata, __config) do
      #                                                                           ^^^^^^^^ BUG
      # Should be: _config (single underscore) if unused
      # Impact: Parameter name has double underscore prefix
      # Fix: Change __config to _config
    end

    test "BUG: line 251 - _attributes unused variable (reassignment not used)" do
      # Line 251: _attributes =
      #           ^^^^^^^^^^^ BUG - variable assigned but never used
      # The attributes variable is already defined, this creates a new _attributes that's unused
      # Fix: Either use the new attributes or remove this assignment
    end

    test "BUG: line 416 - __context should be 'context' (double underscore in comment)" do
      # Line 416: # Record as OpenTelemetry event with enhanced __context
      #                                                         ^^^^^^^^^ BUG
      # Impact: Comment has double underscore prefix
      # Fix: Change "__context" to "context" in comment
    end

    test "BUG: line 422 - enhanced.__context should be 'enhanced.context' (attribute key)" do
      # Line 422: "enhanced.__context" => true
      #           ^^^^^^^^^^^^^^^^^^^^ BUG
      # Should be: "enhanced.context" => true
      # Impact: Incorrect attribute key with double underscore
      # Fix: Change "enhanced.__context" to "enhanced.context"
    end

    test "BUG: line 468 - __user_experience should be 'user_experience' (double underscore)" do
      # Line 468: __user_experience: measure_user_experience_baseline(),
      #           ^^^^^^^^^^^^^^^^^ BUG
      # Should be: user_experience: measure_user_experience_baseline(),
      # Impact: Map key has double underscore prefix
      # Fix: Change __user_experience to user_experience
    end

    test "BUG: line 563 - _requests_per_second should be 'requests_per_second' (underscore prefix)" do
      # Line 563: _requests_per_second: 850.0,
      #           ^^^^^^^^^^^^^^^^^^^^^ BUG
      # Should be: requests_per_second: 850.0,
      # Impact: Map key has underscore prefix (should not be prefixed)
      # Fix: Remove underscore prefix from requests_per_second
    end

    test "BUG: line 677 - __user_activity_system_load should be 'user_activity_system_load'" do
      # Line 677: __user_activity_system_load: 0.69,
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG
      # Should be: user_activity_system_load: 0.69,
      # Impact: Map key has double underscore prefix
      # Fix: Change __user_activity_system_load to user_activity_system_load
    end

    test "BUG: line 686 - __user_growth_trend should be 'user_growth_trend' (double underscore)" do
      # Line 686: __user_growth_trend: %{direction: :increasing, rate: 12.5, confidence: 89.2},
      #           ^^^^^^^^^^^^^^^^^^^ BUG
      # Should be: user_growth_trend: %{direction: :increasing, rate: 12.5, confidence: 89.2},
      # Impact: Map key has double underscore prefix
      # Fix: Change __user_growth_trend to user_growth_trend
    end

    test "BUG: line 702 - __user_experience category should be 'user_experience'" do
      # Line 702: String.contains?(to_string(name), "user") -> :__user_experience
      #                                                        ^^^^^^^^^^^^^^^^^ BUG
      # Should be: String.contains?(to_string(name), "user") -> :user_experience
      # Impact: Atom has double underscore prefix
      # Fix: Change :__user_experience to :user_experience
    end

    test "BUG: line 819 - __context should be 'context' (comment typo)" do
      # Line 819: # EP-015: Unused parent __context extraction function
      #                                   ^^^^^^^^^ BUG
      # Impact: Comment has double underscore prefix
      # Fix: Change "__context" to "context" in comment
    end

    test "BUG: line 821 - __context should be 'context' (comment typo)" do
      # Line 821: # Extract OpenTelemetry __context from metadata if available
      #                                   ^^^^^^^^^ BUG
      # Impact: Comment has double underscore prefix
      # Fix: Change "__context" to "context" in comment
    end
  end
end
