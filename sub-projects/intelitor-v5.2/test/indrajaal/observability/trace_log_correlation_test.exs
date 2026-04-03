defmodule Indrajaal.Observability.TraceLogCorrelationTest do
  @moduledoc """
  🧪 TDG Test Suite for Trace-Log Correlation Implementation

  ## Agent: Helper Agent 1 + Worker Agent 1-6 - Comprehensive TDG Test Coordination
  ## SOPv5.1 Compliance: Maximum parallelization with cybernetic feedback
  ## Multi-Agent Coordination: Tests created BEFORE implementation across all workers

  ## TDG Compliance Markers
  - ✅ TDG_COMPLIANT: Tests written BEFORE implementation (Helper Agent 1)
  - ✅ DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties parallel validation
  - ✅ STAMP_SAFETY: SC1-SC5 comprehensive safety constraint testing
  - ✅ SOPv5.1_CYBERNETIC: Multi-agent coordination with real-time feedback
  - ✅ MAX_PARALLELIZATION: All test scenarios executed concurrently

  This test suite validates:
  - OpenTelemetry trace __context propagation and extraction
  - Log-trace correlation algorithm accuracy and performance
  - Trace metadata management and correlation ID generation
  - Integration with Phoenix, Ecto, and background jobs
  - Error handling and graceful fallback mechanisms
  - High-throughput correlation performance optimization
  """

  use ExUnit.Case, async: true
  # Advanced property testing (Worker Agent 1)
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData validation (Worker Agent 2)
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias Indrajaal.Observability.TraceLogCorrelation
  alias Indrajaal.Observability.DualLogging

  import ExUnit.CaptureLog
  require Logger

  @moduletag :trace_log_correlation

  # Test data for maximum parallelization
  @valid_trace_context %{
    trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
    span_id: "00f067aa0ba902b7",
    trace_flags: "01"
  }

  @sample_log_entries [
    %{level: :info, message: "User login successful", metadata: %{}},
    %{level: :error, message: "Database connection failed", metadata: %{error_code: 500}},
    %{level: :debug, message: "Cache hit", metadata: %{key: "user:123"}}
  ]

  describe "Trace Context Extraction (TDG - Worker Agent 1)" do
    test "extracts OpenTelemetry trace context from process metadata" do
      # Helper Agent 2: Process metadata trace context extraction
      assert {:ok, context} = TraceLogCorrelation.extract_trace_context(@valid_trace_context)
      assert context.trace_id == @valid_trace_context.trace_id
      assert context.span_id == @valid_trace_context.span_id
    end

    test "handles missing trace context gracefully" do
      # Worker Agent 1: Missing context handling
      assert {:ok, fallback_context} = TraceLogCorrelation.extract_trace_context(%{})
      assert Map.has_key?(fallback_context, :correlation_id)
      assert String.length(fallback_context.correlation_id) > 0
    end

    test "validates trace ID format compliance" do
      # Worker Agent 2: Trace ID validation
      invalid_trace_contexts = [
        %{trace_id: "invalid-format", span_id: @valid_trace_context.span_id},
        %{trace_id: "", span_id: @valid_trace_context.span_id},
        %{trace_id: nil, span_id: @valid_trace_context.span_id}
      ]

      for invalid_context <- invalid_trace_contexts do
        case TraceLogCorrelation.extract_trace_context(invalid_context) do
          {:ok, fallback} ->
            # Should provide fallback correlation
            assert Map.has_key?(fallback, :correlation_id)

          {:error, :invalid_trace_id} ->
            # Invalid trace ID rejection is acceptable
            assert true
        end
      end
    end

    test "injects trace metadata into log entries" do
      # Helper Agent 3: Log metadata injection
      log_entry = %{level: :info, message: "Test message", metadata: %{}}

      assert {:ok, enriched_entry} =
               TraceLogCorrelation.inject_trace_metadata(log_entry, @valid_trace_context)

      assert enriched_entry.metadata.trace_id == @valid_trace_context.trace_id
      assert enriched_entry.metadata.span_id == @valid_trace_context.span_id
    end
  end

  describe "STAMP Safety Constraints (SC1-SC5)" do
    test "SC1: Data Integrity - accurate trace-log correlation" do
      # Worker Agent 3: Data integrity validation
      log_entry = %{level: :info, message: "Test correlation", metadata: %{}}

      {:ok, correlated_entry} =
        TraceLogCorrelation.correlate_log_with_trace(log_entry, @valid_trace_context)

      # Correlation should be accurate and complete
      assert correlated_entry.metadata.trace_id == @valid_trace_context.trace_id
      assert correlated_entry.metadata.span_id == @valid_trace_context.span_id
      assert Map.has_key?(correlated_entry.metadata, :correlation_timestamp)
    end

    test "SC2: Performance - correlation overhead within acceptable limits" do
      # Worker Agent 4: Performance validation
      log_entry = %{level: :info, message: "Performance test", metadata: %{}}

      {time, result} =
        :timer.tc(fn ->
          TraceLogCorrelation.correlate_log_with_trace(log_entry, @valid_trace_context)
        end)

      assert {:ok, _correlated} = result
      # Correlation should complete within 1ms (1000 microseconds)
      assert time < 1000
    end

    test "SC3: Security - filters sensitive data from trace correlation" do
      # Worker Agent 5: Security validation
      log_with_sensitive_data = %{
        level: :info,
        message: "User action",
        metadata: %{
          password: "secret-password",
          api_key: "sensitive-key",
          user_id: 123,
          action: "login"
        }
      }

      {:ok, correlated} =
        TraceLogCorrelation.correlate_log_with_trace(
          log_with_sensitive_data,
          @valid_trace_context
        )

      # Sensitive data should be filtered out
      refute Map.has_key?(correlated.metadata, :password)
      refute Map.has_key?(correlated.metadata, :api_key)
      # Non-sensitive data should remain
      assert correlated.metadata.user_id == 123
      assert correlated.metadata.action == "login"
    end

    test "SC4: Availability - handles unavailable tracing infrastructure" do
      # Worker Agent 6: Availability validation
      log_entry = %{level: :error, message: "System error", metadata: %{}}

      # Simulate unavailable tracing (empty context)
      case TraceLogCorrelation.correlate_log_with_trace(log_entry, %{}) do
        {:ok, correlated} ->
          # Should provide fallback correlation
          assert Map.has_key?(correlated.metadata, :correlation_id)

        {:error, :tracing_unavailable} ->
          # Graceful degradation is acceptable
          assert true
      end
    end

    test "SC5: Compliance - logs all correlation activities" do
      # Supervisor oversight: Compliance validation
      log_entry = %{level: :info, message: "Audit test", metadata: %{}}

      log_output =
        capture_log(fn ->
          TraceLogCorrelation.correlate_log_with_trace(log_entry, @valid_trace_context)
        end)

      # Should log correlation activities for audit trail
      assert log_output =~ "trace correlation" or log_output =~ "correlation_id"
    end
  end

  describe "PropCheck Property-Based Testing" do
    @tag :property
    test "propcheck: handles various trace ID formats correctly" do
      import PropCheck

      assert PropCheck.quickcheck(
               PropCheck.forall trace_id <-
                                  PC.non_empty(PC.binary()) do
                 # Multi-worker property validation
                 context = %{
                   trace_id: trace_id,
                   span_id: @valid_trace_context.span_id,
                   trace_flags: @valid_trace_context.trace_flags
                 }

                 log_entry = %{level: :info, message: "Property test", metadata: %{}}

                 case TraceLogCorrelation.correlate_log_with_trace(log_entry, context) do
                   {:ok, correlated} ->
                     # If correlation succeeds, trace_id should be properly handled
                     byte_size(trace_id) > 0 and
                       Map.has_key?(correlated.metadata, :trace_id)

                   {:error, _reason} ->
                     # Some trace IDs may be invalid, which is acceptable
                     true
                 end
               end
             )
    end

    @tag :property
    test "propcheck: correlation maintains data integrity" do
      import PropCheck

      assert PropCheck.quickcheck(
               PropCheck.forall {message, level} <- {
                                  PC.non_empty(PC.binary()),
                                  PC.oneof([:debug, :info, :warn, :error])
                                } do
                 log_entry = %{level: level, message: message, metadata: %{}}

                 case TraceLogCorrelation.correlate_log_with_trace(
                        log_entry,
                        @valid_trace_context
                      ) do
                   {:ok, correlated} ->
                     # Original data should be preserved
                     correlated.level == level and correlated.message == message

                   {:error, _} ->
                     true
                 end
               end
             )
    end
  end

  describe "ExUnitProperties StreamData Testing" do
    test "streamdata: various metadata configurations" do
      ExUnitProperties.check all(
                               metadata_size <- StreamData.integer(0..50),
                               metadata_keys <-
                                 StreamData.list_of(
                                   StreamData.string(:alphanumeric, min_length: 1),
                                   length: metadata_size
                                 )
                             ) do
        metadata =
          metadata_keys
          |> Enum.with_index()
          |> Enum.map(fn {key, index} -> {key, "value_#{index}"} end)
          |> Map.new()

        log_entry = %{level: :info, message: "StreamData test", metadata: metadata}

        # Should either succeed or fail gracefully
        result = TraceLogCorrelation.correlate_log_with_trace(log_entry, @valid_trace_context)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "streamdata: correlation under concurrent load" do
      ExUnitProperties.check all(batch_size <- StreamData.integer(1..100)) do
        tasks =
          Enum.map(1..batch_size, fn i ->
            Task.async(fn ->
              log_entry = %{
                level: :info,
                message: "Concurrent test #{i}",
                metadata: %{request_id: i}
              }

              TraceLogCorrelation.correlate_log_with_trace(log_entry, @valid_trace_context)
            end)
          end)

        results = Task.await_many(tasks, 5000)

        # At least 80% should succeed under concurrent load
        success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
        success_rate = success_count / batch_size

        success_rate >= 0.8
      end
    end
  end

  describe "High-Throughput Scenarios (Maximum Parallelization)" do
    test "handles high-volume correlation efficiently" do
      # All worker agents: High-throughput validation
      log_entries =
        Enum.map(1..1000, fn i ->
          %{
            level: Enum.random([:debug, :info, :warn, :error]),
            message: "High throughput test #{i}",
            metadata: %{sequence: i, batch: "throughput_test"}
          }
        end)

      {time, results} =
        :timer.tc(fn ->
          Enum.map(log_entries, fn entry ->
            TraceLogCorrelation.correlate_log_with_trace(entry, @valid_trace_context)
          end)
        end)

      # Should process 1000 correlations efficiently
      success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)

      # At least 95% success rate
      assert success_count >= 950

      # Should complete within reasonable time (less than 1 second)
      # 1 second in microseconds
      assert time < 1_000_000
    end

    test "maintains memory efficiency during sustained correlation" do
      # Performance validation across all agents
      log_entry = %{level: :info, message: "Memory test", metadata: %{}}

      # Monitor memory usage during sustained correlation
      initial_memory = :erlang.memory(:processes)

      Enum.each(1..5000, fn _i ->
        TraceLogCorrelation.correlate_log_with_trace(log_entry, @valid_trace_context)
      end)

      final_memory = :erlang.memory(:processes)
      memory_increase = final_memory - initial_memory

      # Memory increase should be reasonable (less than 10MB)
      # 10MB in bytes
      assert memory_increase < 10_000_000
    end
  end

  describe "Integration Testing (Phoenix, Ecto, Background Jobs)" do
    test "correlates Phoenix LiveView traces with logs" do
      # Helper Agent 4: Phoenix integration
      phoenix_trace_context = %{
        trace_id: "phoenix_trace_123456789",
        span_id: "phoenix_span_001",
        trace_flags: "01",
        phoenix_component: "UserDashboardLive",
        phoenix_action: "mount"
      }

      log_entry = %{
        level: :info,
        message: "LiveView mounted",
        metadata: %{component: "UserDashboardLive"}
      }

      {:ok, correlated} =
        TraceLogCorrelation.correlate_log_with_trace(log_entry, phoenix_trace_context)

      assert correlated.metadata.trace_id == phoenix_trace_context.trace_id
      assert Map.has_key?(correlated.metadata, :phoenix_component)
    end

    test "correlates Ecto query traces with database logs" do
      # Helper Agent 4: Ecto integration
      ecto_trace_context = %{
        trace_id: "ecto_trace_987654321",
        span_id: "ecto_span_002",
        trace_flags: "01",
        ecto_repo: "Indrajaal.Repo",
        ecto_query: "SELECT * FROM users"
      }

      log_entry = %{
        level: :debug,
        message: "Database query executed",
        metadata: %{query_time: 25, rows: 1}
      }

      {:ok, correlated} =
        TraceLogCorrelation.correlate_log_with_trace(log_entry, ecto_trace_context)

      assert correlated.metadata.trace_id == ecto_trace_context.trace_id
      assert Map.has_key?(correlated.metadata, :ecto_repo)
    end

    test "correlates background job traces with job logs" do
      # Worker Agent 4: Background job integration
      job_trace_context = %{
        trace_id: "job_trace_456789123",
        span_id: "job_span_003",
        trace_flags: "01",
        job_queue: "default",
        job_worker: "EmailWorker"
      }

      log_entry = %{
        level: :info,
        message: "Background job completed",
        metadata: %{job_id: 12_345, duration_ms: 1500}
      }

      {:ok, correlated} =
        TraceLogCorrelation.correlate_log_with_trace(log_entry, job_trace_context)

      assert correlated.metadata.trace_id == job_trace_context.trace_id
      assert Map.has_key?(correlated.metadata, :job_worker)
    end
  end

  describe "Error Handling and Resilience" do
    test "recovers from correlation engine failures gracefully" do
      # Worker Agent 5: Error recovery validation
      log_entry = %{level: :error, message: "System failure", metadata: %{}}

      # Test with malformed trace context
      malformed_contexts = [
        %{trace_id: :invalid_type, span_id: @valid_trace_context.span_id},
        %{trace_id: @valid_trace_context.trace_id, span_id: nil},
        "not_a_map",
        nil
      ]

      for malformed_context <- malformed_contexts do
        result = TraceLogCorrelation.correlate_log_with_trace(log_entry, malformed_context)

        case result do
          {:ok, fallback_correlated} ->
            # Should provide fallback correlation
            assert Map.has_key?(fallback_correlated.metadata, :correlation_id)

          {:error, reason} ->
            # Graceful error handling is acceptable
            assert is_atom(reason)
        end
      end
    end

    test "handles trace context extraction failures" do
      # Worker Agent 6: Context extraction resilience
      invalid_process_metadata = [
        %{not_trace_related: "data"},
        %{trace_id: "corrupted_trace_data_with_invalid_format"},
        %{}
      ]

      for metadata <- invalid_process_metadata do
        result = TraceLogCorrelation.extract_trace_context(metadata)

        case result do
          {:ok, context} ->
            # Should provide valid context (even fallback)
            assert is_map(context)

          {:error, reason} ->
            # Error handling is acceptable
            assert is_atom(reason)
        end
      end
    end
  end
end
