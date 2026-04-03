defmodule Indrajaal.Observability.ObservabilityHelpersTest do
  @moduledoc """
  Test suite for shared observability helper functions.

  This module tests:
  - Common observability utilities
  - Metric naming conventions
  - Tag normalization and validation
  - Sampling strategies
  - Context propagation helpers
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.ObservabilityHelpers

  describe "metric naming" do
    test "generates consistent metric names following conventions" do
      # Given a domain and action
      result = ObservabilityHelpers.metric_name(:accounts, :__user_login)

      # Then it should follow naming convention
      assert result == "indrajaal.accounts.__user_login"
    end

    test "handles nested metrics with proper hierarchy" do
      # Given nested metric components
      result = ObservabilityHelpers.metric_name([:api, :v2, :accounts], :create)

      # Then it should create proper hierarchy
      assert result == "indrajaal.api.v2.accounts.create"
    end

    test "normalizes metric names to lowercase with underscores" do
      # Given mixed case input
      result = ObservabilityHelpers.metric_name("UserAccounts", "CreateNew")

      # Then it should normalize
      assert result == "indrajaal.__user_accounts.create_new"
    end

    test "validates metric names against allowed patterns" do
      # Given invalid characters
      assert {:error, :invalid_metric_name} =
               ObservabilityHelpers.metric_name("accounts!", "create$")

      # Given valid name
      assert {:ok, _} = ObservabilityHelpers.validate_metric_name("indrajaal.accounts.create")
    end
  end

  describe "tag normalization" do
    test "normalizes tags to consistent format" do
      # Given various tag formats
      tags = %{
        "UserID" => "123",
        :tenant_id => "tenant_456",
        "status-code" => 200
      }

      # When normalized
      result = ObservabilityHelpers.normalize_tags(tags)

      # Then all should be consistent
      assert result == %{
               __user_id: "123",
               tenant_id: "tenant_456",
               status_code: "200"
             }
    end

    test "filters out sensitive tags" do
      # Given tags with sensitive __data
      tags = %{
        __user_id: "123",
        password: "secret",
        api_key: "key123",
        email: "__user@example.com"
      }

      # When filtered
      result = ObservabilityHelpers.filter_sensitive_tags(tags)

      # Then sensitive __data should be removed or masked
      assert result.__user_id == "123"
      assert result.password == "[REDACTED]"
      assert result.api_key == "[REDACTED]"
      assert result.email == "__user@[REDACTED]"
    end

    test "enforces tag cardinality limits" do
      # Given high cardinality tags
      tags = Map.new(1..100, fn i -> {"tag_#{i}", "value_#{i}"} end)

      # When applying cardinality limits
      result = ObservabilityHelpers.apply_cardinality_limits(tags)

      # Then it should limit tags
      assert map_size(result) <= ObservabilityHelpers.max_tag_count()
      assert result._truncated == true
    end
  end

  describe "sampling strategies" do
    test "applies rate-based sampling correctly" do
      # Given a sampling rate of 10%
      sampler = ObservabilityHelpers.create_sampler(rate: 0.1)

      # When sampling many __requests
      results =
        Enum.map(1..10_000, fn i ->
          ObservabilityHelpers.should_sample?(sampler, %{__request_id: "__req_#{i}"})
        end)

      # Then approximately 10% should be sampled
      sampled_count = Enum.count(results, & &1)
      percentage = sampled_count / 10_000 * 100
      assert percentage > 9.0 and percentage < 11.0
    end

    test "applies priority sampling for important operations" do
      # Given priority sampling rules
      sampler =
        ObservabilityHelpers.create_sampler(
          rate: 0.1,
          priority_rules: [
            {[:error, :critical], 1.0},
            {[:payment, :*], 0.5}
          ]
        )

      # When checking priority operations
      assert ObservabilityHelpers.should_sample?(sampler, %{level: :critical})
      assert ObservabilityHelpers.should_sample?(sampler, %{level: :error})

      # Payment operations have 50% sampling
      payment_results =
        Enum.map(1..1000, fn i ->
          ObservabilityHelpers.should_sample?(sampler, %{operation: :payment, id: i})
        end)

      payment_percentage = Enum.count(payment_results, & &1) / 1000 * 100
      assert payment_percentage > 45.0 and payment_percentage < 55.0
    end

    test "implements adaptive sampling based on load" do
      # Given adaptive sampler
      sampler =
        ObservabilityHelpers.create_adaptive_sampler(
          base_rate: 0.1,
          target_throughput: 100
        )

      # When load increases
      ObservabilityHelpers.record_throughput(sampler, 500)

      # Then sampling rate should decrease
      new_rate = ObservabilityHelpers.get_current_rate(sampler)
      assert new_rate < 0.1
      # Minimum 2% sampling
      assert new_rate >= 0.02
    end
  end

  describe "__context propagation" do
    test "merges __contexts correctly with precedence rules" do
      # Given multiple __contexts
      parent_ctx = %{tenant_id: "tenant_1", __user_id: "__user_1", region: "us-east"}
      child_ctx = %{__user_id: "__user_2", __request_id: "__req_123"}

      # When merging
      result = ObservabilityHelpers.merge_contexts(parent_ctx, child_ctx)

      # Then child should override parent
      assert result.tenant_id == "tenant_1"
      assert result.__user_id == "__user_2"
      assert result.region == "us-east"
      assert result.__request_id == "__req_123"
    end

    test "extracts __context from various sources" do
      # Given a __request with headers
      conn = %{
        assigns: %{current_user: %{id: 123, tenant_id: "tenant_1"}},
        private: %{__request_id: "__req_456"},
        __req_headers: [
          {"x-trace-id", "trace_789"},
          {"x-correlation-id", "corr_012"}
        ]
      }

      # When extracting __context
      result = ObservabilityHelpers.extract_context(conn)

      # Then all sources should be included
      assert result.__user_id == 123
      assert result.tenant_id == "tenant_1"
      assert result.__request_id == "__req_456"
      assert result.trace_id == "trace_789"
      assert result.correlation_id == "corr_012"
    end

    test "serializes __context for propagation" do
      # Given a __context
      context = %{
        trace_id: "trace_123",
        span_id: "span_456",
        tenant_id: "tenant_1",
        baggage: %{feature_flag: "enabled"}
      }

      # When serializing for propagation
      headers = ObservabilityHelpers.__context_to_headers(context)

      # Then it should create proper headers
      assert headers["x-trace-id"] == "trace_123"
      assert headers["x-span-id"] == "span_456"
      assert headers["x-tenant-id"] == "tenant_1"
      assert headers["x-baggage"] == "feature_flag=enabled"
    end
  end

  describe "utility functions" do
    test "calculates percentiles correctly" do
      # Given a list of values
      values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

      # When calculating percentiles
      p50 = ObservabilityHelpers.percentile(values, 50)
      p95 = ObservabilityHelpers.percentile(values, 95)
      p99 = ObservabilityHelpers.percentile(values, 99)

      # Then results should be correct
      assert p50 == 5.5
      assert p95 == 9.5
      assert p99 == 9.9
    end

    test "formats durations in human-readable form" do
      # Given various durations in microseconds
      assert ObservabilityHelpers.format_duration(500) == "500μs"
      assert ObservabilityHelpers.format_duration(1_500) == "1.5ms"
      assert ObservabilityHelpers.format_duration(1_500_000) == "1.5s"
      assert ObservabilityHelpers.format_duration(90_000_000) == "1m 30s"
    end

    test "generates correlation IDs with proper format" do
      # When generating IDs
      id1 = ObservabilityHelpers.generate_correlation_id()
      id2 = ObservabilityHelpers.generate_correlation_id()

      # Then they should be unique and properly formatted
      assert id1 != id2
      assert String.match?(id1, ~r/^[a-f0-9]{32}$/)
      assert String.length(id1) == 32
    end
  end

  describe "STAMP safety validations" do
    test "validates observation points don't create infinite loops" do
      # Given a recursive function
      defmodule RecursiveModule do
        def recursive_call(n) when n <= 0, do: :ok
        def recursive_call(n), do: recursive_call(n - 1)
      end

      # When adding observation
      result =
        ObservabilityHelpers.add_observation_point(
          RecursiveModule,
          :recursive_call,
          max_depth: 10
        )

      # Then it should enforce depth limits
      assert {:ok, _} = result
      assert RecursiveModule.recursive_call(15) == :ok
      assert ObservabilityHelpers.get_observation_depth(RecursiveModule) <= 10
    end

    test "prevents observation in critical paths" do
      # Given a critical path function
      critical_paths = ObservabilityHelpers.get_critical_paths()

      # When trying to add observation
      result =
        ObservabilityHelpers.add_observation_point(
          Process,
          :send,
          %{}
        )

      # Then it should be rejected
      assert {:error, :critical_path} = result
    end
  end
end
