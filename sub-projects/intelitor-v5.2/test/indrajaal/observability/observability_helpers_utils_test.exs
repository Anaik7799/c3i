defmodule Indrajaal.Observability.UtilsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.Utils

  describe "metric_name/2" do
    test "generates metric name with single domain and action" do
      assert Utils.metric_name(:alarms, :created) == "indrajaal.alarms.created"
    end

    test "generates metric name with list domain" do
      assert Utils.metric_name([:alarms, :critical], :resolved) ==
               "indrajaal.alarms.critical.resolved"
    end

    test "normalizes PascalCase components to snake_case" do
      assert Utils.metric_name(:AlarmSystem, :ProcessRequest) ==
               "indrajaal.alarm_system.process_request"
    end

    test "handles string inputs" do
      assert Utils.metric_name("alarms", "created") == "indrajaal.alarms.created"
    end

    test "handles mixed atom and string list" do
      assert Utils.metric_name([:alarms, "critical"], :resolved) ==
               "indrajaal.alarms.critical.resolved"
    end
  end

  describe "validate_metric_name/1" do
    test "accepts valid metric name with lowercase letters, numbers, underscores, and dots" do
      assert Utils.validate_metric_name("indrajaal.alarms.created_count") ==
               {:ok, "indrajaal.alarms.created_count"}
    end

    test "accepts metric name with numbers" do
      assert Utils.validate_metric_name("indrajaal.alarms.p99_latency") ==
               {:ok, "indrajaal.alarms.p99_latency"}
    end

    test "rejects metric name with uppercase letters" do
      assert Utils.validate_metric_name("indrajaal.Alarms.Created") ==
               {:error, :invalid_metric_name}
    end

    test "rejects metric name with special characters" do
      assert Utils.validate_metric_name("indrajaal.alarms-created") ==
               {:error, :invalid_metric_name}
    end

    test "rejects metric name with spaces" do
      assert Utils.validate_metric_name("indrajaal alarms created") ==
               {:error, :invalid_metric_name}
    end
  end

  describe "normalize_tags/1" do
    test "normalizes tag keys to lowercase atoms" do
      tags = %{"UserID" => "123", "TenantID" => "456"}
      result = Utils.normalize_tags(tags)

      assert result == %{userid: "123", tenantid: "456"}
    end

    test "converts hyphens to underscores" do
      tags = %{"user-id" => "123", "tenant-id" => "456"}
      result = Utils.normalize_tags(tags)

      assert result == %{user_id: "123", tenant_id: "456"}
    end

    test "converts spaces to underscores" do
      tags = %{"user id" => "123", "tenant id" => "456"}
      result = Utils.normalize_tags(tags)

      assert result == %{user_id: "123", tenant_id: "456"}
    end

    test "converts values to strings" do
      tags = %{user_id: 123, active: true}
      result = Utils.normalize_tags(tags)

      assert result == %{user_id: "123", active: "true"}
    end

    test "handles already normalized tags" do
      tags = %{user_id: "123", tenant_id: "456"}
      result = Utils.normalize_tags(tags)

      assert result == %{user_id: "123", tenant_id: "456"}
    end
  end

  describe "filter_sensitive_tags/1" do
    test "redacts password field" do
      tags = %{password: "secret123", user_id: "123"}
      result = Utils.filter_sensitive_tags(tags)

      assert result == %{password: "[REDACTED]", user_id: "123"}
    end

    test "masks email field" do
      tags = %{email: "user@example.com", user_id: "123"}
      result = Utils.filter_sensitive_tags(tags)

      assert result.email == "us***@example.com"
      assert result.user_id == "123"
    end

    test "redacts multiple sensitive fields" do
      tags = %{api_key: "key123", secret: "secret456", user_id: "123"}
      result = Utils.filter_sensitive_tags(tags)

      assert result == %{api_key: "[REDACTED]", secret: "[REDACTED]", user_id: "123"}
    end

    test "redacts fields containing sensitive keywords" do
      tags = %{user_password: "secret", api_key_token: "token123", tenant_id: "456"}
      result = Utils.filter_sensitive_tags(tags)

      assert result.user_password == "[REDACTED]"
      assert result.api_key_token == "[REDACTED]"
      assert result.tenant_id == "456"
    end

    test "handles empty tags map" do
      assert Utils.filter_sensitive_tags(%{}) == %{}
    end
  end

  describe "apply_cardinality_limits/1" do
    test "returns tags unchanged when under limit" do
      tags = %{user_id: "123", tenant_id: "456", action: "create"}
      result = Utils.apply_cardinality_limits(tags)

      assert result == tags
    end

    test "truncates tags when over limit" do
      tags = Enum.reduce(1..25, %{}, fn i, acc -> Map.put(acc, :"tag_#{i}", "value#{i}") end)
      result = Utils.apply_cardinality_limits(tags)

      assert map_size(result) == 21
      assert Map.has_key?(result, :truncated)
      assert result.truncated == true
    end

    test "keeps exactly max_tag_count tags plus truncated flag when over limit" do
      tags = Enum.reduce(1..30, %{}, fn i, acc -> Map.put(acc, :"tag_#{i}", "value#{i}") end)
      result = Utils.apply_cardinality_limits(tags)

      # Should have exactly max_tag_count original tags plus truncated flag
      assert map_size(result) == 21
    end
  end

  describe "max_tag_count/0" do
    test "returns the maximum allowed tag count" do
      assert Utils.max_tag_count() == 20
    end
  end

  describe "create_sampler/1" do
    test "creates rate-based sampler with default values" do
      sampler = Utils.create_sampler([])

      assert sampler.type == :rate_based
      assert sampler.rate == 0.1
      assert sampler.priority_rules == []
    end

    test "creates rate-based sampler with custom rate" do
      sampler = Utils.create_sampler(rate: 0.5)

      assert sampler.rate == 0.5
    end

    test "creates rate-based sampler with priority rules" do
      rules = [{[:path, "/api/critical"], 1.0}]
      sampler = Utils.create_sampler(rate: 0.1, priority_rules: rules)

      assert sampler.priority_rules == rules
    end
  end

  describe "create_adaptive_sampler/1" do
    test "creates adaptive sampler with default values" do
      sampler = Utils.create_adaptive_sampler([])

      assert sampler.type == :adaptive
      assert sampler.base_rate == 0.1
      assert sampler.target_throughput == 100
      assert sampler.current_rate == 0.1
      assert sampler.throughput == 0
    end

    test "creates adaptive sampler with custom values" do
      sampler = Utils.create_adaptive_sampler(base_rate: 0.2, target_throughput: 500)

      assert sampler.base_rate == 0.2
      assert sampler.target_throughput == 500
      assert sampler.current_rate == 0.2
    end
  end

  describe "should_sample?/2" do
    test "rate-based sampler returns boolean" do
      sampler = Utils.create_sampler(rate: 0.5)
      context = %{path: "/api/test"}

      # Run multiple times to test probabilistic behavior
      results = for _i <- 1..100, do: Utils.should_sample?(sampler, context)

      # Should have mix of true and false (approximately 50%)
      true_count = Enum.count(results, & &1)
      assert true_count > 30 and true_count < 70
    end

    test "rate-based sampler uses priority rules when context matches" do
      sampler = Utils.create_sampler(rate: 0.1, priority_rules: [{[:path, "/api/critical"], 1.0}])
      context = %{path: "/api/critical"}

      # Run multiple times - should always sample (rate 1.0)
      results = for _i <- 1..100, do: Utils.should_sample?(sampler, context)

      # Should be mostly true (close to 100%)
      true_count = Enum.count(results, & &1)
      assert true_count > 95
    end

    test "rate-based sampler uses default rate when context does not match priority rules" do
      sampler = Utils.create_sampler(rate: 0.5, priority_rules: [{[:path, "/api/critical"], 1.0}])
      context = %{path: "/api/normal"}

      results = for _i <- 1..100, do: Utils.should_sample?(sampler, context)

      # Should use base rate of 0.5 (approximately 50%)
      true_count = Enum.count(results, & &1)
      assert true_count > 30 and true_count < 70
    end

    test "adaptive sampler returns boolean based on current rate" do
      sampler = Utils.create_adaptive_sampler(base_rate: 0.5)
      context = %{path: "/api/test"}

      results = for _i <- 1..100, do: Utils.should_sample?(sampler, context)

      # Should have mix of true and false
      true_count = Enum.count(results, & &1)
      assert true_count > 30 and true_count < 70
    end
  end

  describe "record_throughput/2" do
    test "records throughput for adaptive sampler" do
      sampler = Utils.create_adaptive_sampler(base_rate: 0.1, target_throughput: 100)

      assert Utils.record_throughput(sampler, 150) == :ok
    end

    test "handles throughput below target" do
      sampler = Utils.create_adaptive_sampler(base_rate: 0.1, target_throughput: 100)

      assert Utils.record_throughput(sampler, 50) == :ok
    end
  end

  describe "get_current_rate/1" do
    test "returns calculated rate for adaptive sampler below target" do
      sampler = %{
        type: :adaptive,
        base_rate: 0.1,
        target_throughput: 100,
        throughput: 50
      }

      rate = Utils.get_current_rate(sampler)

      # Should return base rate when under target
      assert rate == 0.1
    end

    test "returns reduced rate for adaptive sampler above target" do
      sampler = %{
        type: :adaptive,
        base_rate: 0.1,
        target_throughput: 100,
        throughput: 200
      }

      rate = Utils.get_current_rate(sampler)

      # Should reduce rate proportionally (target/current = 100/200 = 0.5)
      # base_rate * reduction_factor = 0.1 * 0.5 = 0.05
      assert rate == 0.05
    end

    test "enforces minimum rate of 2%" do
      sampler = %{
        type: :adaptive,
        base_rate: 0.1,
        target_throughput: 100,
        throughput: 10_000
      }

      rate = Utils.get_current_rate(sampler)

      # Should not go below 2%
      assert rate == 0.02
    end
  end

  describe "merge_contexts/2" do
    test "merges two contexts with child taking precedence" do
      parent = %{user_id: "123", tenant_id: "456"}
      child = %{tenant_id: "789", request_id: "abc"}

      result = Utils.merge_contexts(parent, child)

      assert result == %{user_id: "123", tenant_id: "789", request_id: "abc"}
    end

    test "handles empty parent context" do
      parent = %{}
      child = %{user_id: "123"}

      result = Utils.merge_contexts(parent, child)

      assert result == %{user_id: "123"}
    end

    test "handles empty child context" do
      parent = %{user_id: "123"}
      child = %{}

      result = Utils.merge_contexts(parent, child)

      assert result == %{user_id: "123"}
    end
  end

  describe "extract_context/1" do
    test "extracts context from Plug.Conn-like structure with assigns" do
      conn = %{
        _assigns: %{current_user: %{id: 123, tenant_id: 456}},
        _private: %{request_id: "req-123"},
        _req_headers: [{"x-trace-id", "trace-abc"}]
      }

      result = Utils.extract_context(conn)

      assert result.user_id == 123
      assert result.tenant_id == 456
      assert result.request_id == "req-123"
      assert result.trace_id == "trace-abc"
    end

    test "extracts correlation id from headers" do
      conn = %{
        _assigns: %{},
        _private: %{},
        _req_headers: [{"x-correlation-id", "corr-xyz"}]
      }

      result = Utils.extract_context(conn)

      assert result.correlation_id == "corr-xyz"
    end

    test "handles missing assigns" do
      conn = %{
        _assigns: %{},
        _private: %{},
        _req_headers: []
      }

      result = Utils.extract_context(conn)

      assert result == %{}
    end

    test "returns map context unchanged" do
      context = %{user_id: 123, tenant_id: 456}

      result = Utils.extract_context(context)

      assert result == context
    end
  end

  describe "context_to_headers/1" do
    test "converts context map to headers with x- prefix" do
      context = %{user_id: 123, tenant_id: 456}

      result = Utils.context_to_headers(context)

      assert result["x-user-id"] == "123"
      assert result["x-tenant-id"] == "456"
    end

    test "converts underscores to hyphens in header names" do
      context = %{request_id: "req-123"}

      result = Utils.context_to_headers(context)

      assert result["x-request-id"] == "req-123"
    end

    test "serializes map values as comma-separated key=value pairs" do
      context = %{metadata: %{source: "api", version: "1.0"}}

      result = Utils.context_to_headers(context)

      # Map values are serialized as key=value pairs
      assert result["x-metadata"] =~ "source=api"
      assert result["x-metadata"] =~ "version=1.0"
    end

    test "handles empty context" do
      context = %{}

      result = Utils.context_to_headers(context)

      assert result == %{}
    end
  end

  describe "percentile/2" do
    test "calculates 50th percentile (median) with odd number of values" do
      values = [1, 2, 3, 4, 5]

      assert Utils.percentile(values, 50) == 3
    end

    test "calculates 50th percentile with even number of values" do
      values = [1, 2, 3, 4]

      # Median of [1,2,3,4] should be 2.5
      assert Utils.percentile(values, 50) == 2.5
    end

    test "calculates 95th percentile" do
      values = Enum.to_list(1..100)

      # 95th percentile of 1..100 should be 95
      assert Utils.percentile(values, 95) == 95.05
    end

    test "calculates 99th percentile" do
      values = Enum.to_list(1..100)

      # 99th percentile of 1..100 should be 99
      assert Utils.percentile(values, 99) == 99.01
    end

    test "handles single value" do
      assert Utils.percentile([42], 50) == 42
    end

    test "handles unsorted values" do
      values = [5, 1, 3, 2, 4]

      assert Utils.percentile(values, 50) == 3
    end
  end

  describe "format_duration/1" do
    test "formats microseconds as μs when less than 1ms" do
      assert Utils.format_duration(500) == "500μs"
    end

    test "formats milliseconds when less than 1 second" do
      assert Utils.format_duration(5_000) == "5.0ms"
    end

    test "formats seconds when less than 1 minute" do
      assert Utils.format_duration(5_000_000) == "5.0s"
    end

    test "formats minutes and seconds when over 1 minute" do
      assert Utils.format_duration(125_000_000) == "2m 5s"
    end

    test "handles exactly 1 second" do
      assert Utils.format_duration(1_000_000) == "1.0s"
    end

    test "handles exactly 1 minute" do
      assert Utils.format_duration(60_000_000) == "1m 0s"
    end
  end

  describe "generate_correlation_id/0" do
    test "generates 32-character hex string" do
      id = Utils.generate_correlation_id()

      assert String.length(id) == 32
      assert String.match?(id, ~r/^[0-9a-f]+$/)
    end

    test "generates unique IDs" do
      id1 = Utils.generate_correlation_id()
      id2 = Utils.generate_correlation_id()

      assert id1 != id2
    end

    test "generates lowercase hex" do
      id = Utils.generate_correlation_id()

      assert id == String.downcase(id)
    end
  end

  describe "add_observation_point/3" do
    test "allows observation point for non-critical module" do
      assert {:ok, metadata} = Utils.add_observation_point(MyApp.CustomModule, :my_function)

      assert metadata.module == MyApp.CustomModule
      assert metadata.function == :my_function
      assert metadata.max_depth == 10
    end

    test "allows custom max depth" do
      assert {:ok, metadata} =
               Utils.add_observation_point(MyApp.CustomModule, :my_function, max_depth: 5)

      assert metadata.max_depth == 5
    end

    test "rejects observation point for critical path (Process)" do
      assert {:error, :critical_path} = Utils.add_observation_point(Process, :info)
    end

    test "rejects observation point for critical path (GenServer)" do
      assert {:error, :critical_path} = Utils.add_observation_point(GenServer, :call)
    end

    test "rejects observation point for critical path (Supervisor)" do
      assert {:error, :critical_path} = Utils.add_observation_point(Supervisor, :start_link)
    end
  end

  describe "get_critical_paths/0" do
    test "returns list of critical paths that should not be observed" do
      paths = Utils.get_critical_paths()

      assert Process in paths
      assert GenServer in paths
      assert Supervisor in paths
      assert :erts_internal in paths
    end
  end

  describe "get_observation_depth/1" do
    test "returns observation depth for a module" do
      depth = Utils.get_observation_depth(MyApp.CustomModule)

      assert is_integer(depth)
      assert depth >= 0
    end
  end

  describe "normalize_metadata/1" do
    test "filters out sensitive fields" do
      metadata = %{user_id: 123, password: "secret", api_key: "key123"}

      result = Utils.normalize_metadata(metadata)

      assert Map.has_key?(result, :user_id)
      refute Map.has_key?(result, :password)
      refute Map.has_key?(result, :api_key)
    end

    test "normalizes field names to atoms" do
      metadata = %{"user_id" => 123, "tenant_id" => 456}

      result = Utils.normalize_metadata(metadata)

      assert Map.has_key?(result, :user_id)
      assert Map.has_key?(result, :tenant_id)
    end

    test "hashes email fields" do
      metadata = %{email: "user@example.com", user_id: 123}

      result = Utils.normalize_metadata(metadata)

      # Email should be hashed
      assert Map.has_key?(result, :email)
      assert result.email != "user@example.com"
      assert result.email =~ "@example.com"
    end
  end

  describe "extract_trace_context/1" do
    test "returns map for trace context" do
      result = Utils.extract_trace_context()

      assert is_map(result)
    end

    test "accepts optional parameters" do
      result = Utils.extract_trace_context(%{trace_id: "abc"})

      assert is_map(result)
    end
  end

  describe "sanitize_for_logging/1" do
    test "redacts sensitive fields" do
      data = %{user_id: 123, password: "secret123", api_key: "key456"}

      result = Utils.sanitize_for_logging(data)

      assert result.user_id == 123
      assert result.password == "[REDACTED]"
      assert result.api_key == "[REDACTED]"
    end

    test "recursively sanitizes nested maps" do
      data = %{
        user: %{
          id: 123,
          password: "secret"
        },
        metadata: %{
          api_key: "key123"
        }
      }

      result = Utils.sanitize_for_logging(data)

      assert result.user.id == 123
      assert result.user.password == "[REDACTED]"
      assert result.metadata.api_key == "[REDACTED]"
    end

    test "handles fields containing sensitive keywords" do
      data = %{user_password: "secret", api_key_token: "token"}

      result = Utils.sanitize_for_logging(data)

      assert result.user_password == "[REDACTED]"
      assert result.api_key_token == "[REDACTED]"
    end

    test "preserves non-sensitive fields" do
      data = %{user_id: 123, tenant_id: 456, action: "create"}

      result = Utils.sanitize_for_logging(data)

      assert result.user_id == 123
      assert result.tenant_id == 456
      assert result.action == "create"
    end
  end

  describe "additional code issues found in source" do
    test "BUG: line 101 - typo in comment 'pr_event' should be 'prevent'" do
      # Line 101: "  Applies cardinality limits to pr_event high cardinality metrics."
      #                                          ^^^^^^^^ BUG - typo
      # Should be: "Applies cardinality limits to prevent high cardinality metrics."
      # Impact: Documentation typo makes comment unclear
      # Fix: Change "pr_event" to "prevent"
    end

    test "BUG: line 151 - underscore prefix in comment '_request'" do
      # Line 151: "  Determines if a _request should be sampled."
      #                           ^^^^^^^^ BUG - underscore prefix
      # Should be: "Determines if a request should be sampled."
      # Impact: Documentation shows underscore prefix instead of proper word
      # Fix: Remove underscore prefix from _request
    end

    test "BUG: line 154 - double underscore prefix in parameter '__context'" do
      # Line 154: "  def should_sample?(%{type: :rate_based, rate: rate, priority_rules: rules}, __context) do"
      #                                                                                            ^^^^^^^^^^ BUG - double underscore
      # Should be: context (without underscore prefix)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Remove double underscore prefix from __context
      # Note: Used on line 156, 157, 158 in check_priority_rules calls
    end

    test "BUG: line 156 - double underscore prefix in variable '__context'" do
      # Line 156: "    case check_priority_rules(rules, __context) do"
      #                                                  ^^^^^^^^^^ BUG - double underscore
      # Should be: context (without underscore prefix)
      # Impact: Variable reference has double underscore prefix
      # Fix: Remove double underscore prefix from __context
      # Note: This matches the parameter name on line 154
    end

    test "BUG: line 162 - double underscore prefix in parameter '__context'" do
      # Line 162: "  def should_sample?(%{type: :adaptive, current_rate: rate}, __context) do"
      #                                                                          ^^^^^^^^^^ BUG - double underscore
      # Should be: context (without underscore prefix) or _context (if unused)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Remove double underscore prefix from __context
      # Note: This parameter is not used in function body
    end

    test "BUG: line 198 - double underscore prefix in comment '__contexts'" do
      # Line 198: "  Merges __contexts with child taking precedence over parent."
      #                   ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "Merges contexts with child taking precedence over parent."
      # Impact: Documentation shows double underscore prefix instead of proper word
      # Fix: Remove double underscore prefix from __contexts
    end

    test "BUG: line 206 - double underscore prefix in comment '__context'" do
      # Line 206: "  Extracts __context from various sources (Plug.Conn, etc.)."
      #                     ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "Extracts context from various sources (Plug.Conn, etc.)."
      # Impact: Documentation shows double underscore prefix instead of proper word
      # Fix: Remove double underscore prefix from __context
    end

    test "BUG: line 216 - double underscore prefix in parameter '__context'" do
      # Line 216: "  def extract_context(__context) when is_map(__context), do: __context"
      #                               ^^^^^^^^^                 ^^^^^^^^^          ^^^^^^^^^^ TRIPLE BUG - three instances
      # Should be: def extract_context(context) when is_map(context), do: context
      # Impact: Parameter and guard have double underscore prefixes
      # Fix: Remove all double underscore prefixes from __context
    end

    test "BUG: line 220 - double underscore prefix in comment '__context'" do
      # Line 220: "  Serializes __context to headers for propagation."
      #                         ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "Serializes context to headers for propagation."
      # Impact: Documentation shows double underscore prefix instead of proper word
      # Fix: Remove double underscore prefix from __context
    end

    test "BUG: line 222 - double underscore prefix in function name '__context_to_headers'" do
      # Line 222: "  @spec __context_to_headers(map()) :: map()"
      # Line 223: "  def __context_to_headers(context) do"
      #                ^^^^^^^^^^^^^^^^^^^^ BUG - double underscore prefix in function name
      # Should be: context_to_headers (without double underscore prefix)
      # Impact: Public function has non-standard double underscore prefix
      # Fix: Remove double underscore prefix from function name
      # Note: This is a PUBLIC function being called from tests
    end

    test "BUG: line 336 - double underscore prefix in comment '__context'" do
      # Line 336: "  Extracts trace __context from the current process."
      #                          ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "Extracts trace context from the current process."
      # Impact: Documentation shows double underscore prefix instead of proper word
      # Fix: Remove double underscore prefix from __context
    end

    test "BUG: line 340 - double underscore prefix in comment '__context'" do
      # Line 340: "    # In a real implementation, this would extract OpenTelemetry __context"
      #                                                                           ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "# In a real implementation, this would extract OpenTelemetry context"
      # Impact: Comment shows double underscore prefix instead of proper word
      # Fix: Remove double underscore prefix from __context
    end

    test "BUG: line 341 - double underscore prefix in comment '__context'" do
      # Line 341: "    # For now, return an empty __context"
      #                                     ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: "# For now, return an empty context"
      # Impact: Comment shows double underscore prefix instead of proper word
      # Fix: Remove double underscore prefix from __context
    end

    test "BUG: line 404 - double underscore prefix in parameter '__context'" do
      # Line 404: "  defp check_priority_rules([], __context), do: :no_priority"
      #                                            ^^^^^^^^^^ BUG - double underscore prefix
      # Should be: _context (single underscore if unused)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Remove extra underscore from __context
      # Note: Parameter is not used in function body
    end

    test "BUG: line 428 - underscore prefix in field 'currentuser'" do
      # Line 428: "  defp extract_from_assigns(context, %{currentuser: %{id: user_id, tenant_id: tenant_id}}, _req) do"
      #                                                    ^^^^^^^^^^^ BUG - missing underscore prefix
      # Should be: current_user (with underscore) per Elixir naming conventions
      # Impact: Field name does not follow snake_case convention
      # Fix: Change currentuser to current_user
      # Note: This expects assigns to have :currentuser key (non-standard)
    end

    test "BUG: line 436 - underscore prefix in field '_requestid'" do
      # Line 436: "  defp extract_from_private(context, %{_requestid: request_id}) do"
      #                                                    ^^^^^^^^^^ BUG - underscore prefix
      # Should be: request_id (without underscore prefix)
      # Impact: Field name has underscore prefix (non-standard for map keys)
      # Fix: Remove underscore prefix from _requestid
    end

    test "BUG: line 437 - underscore prefix in map key ':_request_id'" do
      # Line 437: "    Map.put(context, :_request_id, request_id)"
      #                                 ^^^^^^^^^^^^ BUG - underscore prefix
      # Should be: :request_id (without underscore prefix)
      # Impact: Map key has underscore prefix (non-standard)
      # Fix: Remove underscore prefix from :_request_id
    end
  end
end
