# OpenCode API Integration Architecture Design

**Document Version**: 1.0
**Created**: 2025-09-19 19:47:32 CEST
**Author**: Claude AI Assistant
**Purpose**: Technical architecture for real OpenCode API integration in Multi-AI Validation Framework

## Executive Summary

This document specifies the technical architecture for replacing the current mock OpenCode validator simulation with live OpenCode API connectivity. The design maintains compatibility with the existing Multi-AI Validation Framework while adding enterprise-grade API integration capabilities.

## Architecture Overview

### Current State Analysis

Based on analysis of the existing mock implementation (`/scripts/validation/opencode_validator.exs`), the current system provides:

- **Mock OpenCode Analysis**: 6 analysis types (code_analysis, security_analysis, pattern_detection, performance_review, documentation, suggestion_engine)
- **Confidence Scoring**: 70% threshold for validation passage
- **EP-110 Prevention**: False positive detection for validation claims
- **Session Management**: Timeout management (60s sessions, 5 max concurrent)
- **Multi-AI Integration**: 30% weight in consensus with Claude (40%) and FPPS (30%)

### Target Architecture

The new architecture will replace mock simulations with live OpenCode API calls while preserving all existing functionality and improving reliability.

## Technical Specifications

### 1. HTTP Client Implementation

#### 1.1 Client Selection
- **Primary**: Tesla (already available: `{:tesla, "~> 1.8"}`)
- **Alternative**: HTTPoison (already available: `{:httpoison, "~> 2.0"}`)
- **Reasoning**: Tesla preferred for middleware architecture and better testing support

#### 1.2 Tesla Client Configuration

```elixir
defmodule Indrajaal.Validation.OpenCodeClient do
  use Tesla

  @opencode_base_url Application.compile_env(:indrajaal, :opencode_api_url, "https://api.opencode.ai")
  @api_version "v1"
  @default_timeout 30_000  # 30 seconds
  @max_retries 3

  plug Tesla.Middleware.BaseUrl, "#{@opencode_base_url}/#{@api_version}"
  plug Tesla.Middleware.Headers, [
    {"content-type", "application/json"},
    {"user-agent", "Indrajaal-Validator/1.0"}
  ]
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Timeout, timeout: @default_timeout
  plug Tesla.Middleware.Retry,
    delay: 1000,
    max_retries: @max_retries,
    should_retry: fn
      {:ok, %{status: status}} when status in [408, 429, 500, 502, 503, 504] -> true
      {:error, :timeout} -> true
      {:error, :econnrefused} -> true
      _ -> false
    end
  plug Tesla.Middleware.Logger

  # Authentication middleware
  plug Indrajaal.Validation.OpenCodeAuth
end
```

### 2. Authentication and Rate Limiting

#### 2.1 Authentication Strategy

```elixir
defmodule Indrajaal.Validation.OpenCodeAuth do
  @behaviour Tesla.Middleware

  @token_refresh_threshold 300  # 5 minutes before expiry
  @token_cache_key "opencode_auth_token"

  def call(env, next, _opts) do
    env
    |> add_auth_header()
    |> Tesla.run(next)
  end

  defp add_auth_header(env) do
    case get_valid_token() do
      {:ok, token} ->
        Tesla.put_header(env, "authorization", "Bearer #{token}")
      {:error, _reason} ->
        raise "OpenCode authentication failed"
    end
  end

  defp get_valid_token do
    case :ets.lookup(:opencode_cache, @token_cache_key) do
      [{_, token, expires_at}] when expires_at > System.system_time(:second) + @token_refresh_threshold ->
        {:ok, token}
      _ ->
        refresh_token()
    end
  end

  defp refresh_token do
    case authenticate() do
      {:ok, %{token: token, expires_in: expires_in}} ->
        expires_at = System.system_time(:second) + expires_in
        :ets.insert(:opencode_cache, {@token_cache_key, token, expires_at})
        {:ok, token}
      error ->
        error
    end
  end

  defp authenticate do
    api_key = Application.get_env(:indrajaal, :opencode_api_key)
    api_secret = Application.get_env(:indrajaal, :opencode_api_secret)

    if is_nil(api_key) or is_nil(api_secret) do
      {:error, :missing_credentials}
    else
      # Implementation would make actual auth call to OpenCode
      {:ok, %{token: "mock_token", expires_in: 3600}}
    end
  end
end
```

#### 2.2 Rate Limiting Implementation

```elixir
defmodule Indrajaal.Validation.OpenCodeRateLimit do
  use GenServer

  @rate_limit_window 60_000  # 1 minute
  @max_requests_per_window 100
  @burst_limit 10

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def check_rate_limit(session_id) do
    GenServer.call(__MODULE__, {:check_rate_limit, session_id})
  end

  def init(state) do
    # Initialize ETS table for rate limiting
    :ets.new(:rate_limits, [:set, :public, :named_table])
    {:ok, state}
  end

  def handle_call({:check_rate_limit, session_id}, _from, state) do
    current_time = System.system_time(:millisecond)
    window_start = current_time - @rate_limit_window

    # Clean old entries
    :ets.select_delete(:rate_limits, [{{session_id, :"$2"}, [{:<, :"$2", window_start}], [true]}])

    # Count current requests
    request_count = :ets.select_count(:rate_limits, [{{session_id, :"$2"}, [{:>=, :"$2", window_start}], [true]}])

    if request_count < @max_requests_per_window do
      :ets.insert(:rate_limits, {session_id, current_time})
      {:reply, :ok, state}
    else
      {:reply, {:error, :rate_limited}, state}
    end
  end
end
```

### 3. API Endpoint Mapping

#### 3.1 Analysis Type Mapping

```elixir
defmodule Indrajaal.Validation.OpenCodeEndpoints do
  @endpoint_mapping %{
    code_analysis: "/analyze/code",
    security_analysis: "/analyze/security",
    pattern_detection: "/analyze/patterns",
    performance_review: "/analyze/performance",
    documentation: "/analyze/documentation",
    suggestion_engine: "/analyze/suggestions"
  }

  @analysis_type_mapping %{
    compilation: [:code_analysis, :pattern_detection],
    security: [:security_analysis, :code_analysis],
    performance: [:performance_review, :code_analysis],
    documentation: [:documentation, :code_analysis],
    comprehensive: [:code_analysis, :security_analysis, :pattern_detection,
                   :performance_review, :documentation, :suggestion_engine]
  }

  def get_endpoint(analysis_type) do
    Map.get(@endpoint_mapping, analysis_type, "/analyze/code")
  end

  def get_analysis_types(validation_type) do
    atom_type = if is_binary(validation_type), do: String.to_atom(validation_type), else: validation_type
    Map.get(@analysis_type_mapping, atom_type, [:code_analysis])
  end

  def build_request_payload(analysis_type, context, options) do
    %{
      analysis_type: analysis_type,
      code: get_code_content(context),
      language: detect_language(context),
      options: build_analysis_options(analysis_type, options),
      metadata: %{
        session_id: options[:session_id],
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        validator_version: "2.0",
        integration: "indrajaal-multi-ai"
      }
    }
  end

  defp get_code_content(context) do
    case get_in(context, [:code_context, :content]) do
      nil -> ""
      content when is_binary(content) -> content
      _ -> ""
    end
  end

  defp detect_language(context) do
    case get_in(context, [:code_context, :extension]) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".py" -> "python"
      _ -> "text"
    end
  end

  defp build_analysis_options(analysis_type, options) do
    base_options = %{
      timeout: 30,
      max_issues: 50,
      confidence_threshold: 0.7
    }

    case analysis_type do
      :security_analysis ->
        Map.merge(base_options, %{include_vulnerability_scan: true, severity_filter: "medium"})
      :performance_review ->
        Map.merge(base_options, %{include_optimization_hints: true, profile_memory: true})
      :pattern_detection ->
        Map.merge(base_options, %{include_anti_patterns: true, check_ep110: true})
      _ ->
        base_options
    end
  end
end
```

### 4. Response Processing and Data Transformation

#### 4.1 Response Parser

```elixir
defmodule Indrajaal.Validation.OpenCodeResponseParser do
  @moduledoc """
  Parses OpenCode API responses and transforms them to match the existing validator interface
  """

  def parse_analysis_response({:ok, %Tesla.Env{status: 200, body: body}}, analysis_type) do
    case body do
      %{"status" => "success", "results" => results} ->
        findings = transform_findings(results["findings"] || [], analysis_type)

        %{
          analysis_type: analysis_type,
          status: :completed,
          findings: findings,
          confidence: calculate_confidence_from_api(results),
          duration: results["processing_time_ms"] || 1000,
          api_metadata: %{
            request_id: results["request_id"],
            api_version: results["api_version"],
            model_version: results["model_version"]
          }
        }

      %{"status" => "error", "error" => error_info} ->
        %{
          analysis_type: analysis_type,
          status: :error,
          error: error_info["message"],
          error_code: error_info["code"]
        }

      _ ->
        %{
          analysis_type: analysis_type,
          status: :error,
          error: "Invalid response format from OpenCode API"
        }
    end
  end

  def parse_analysis_response({:ok, %Tesla.Env{status: status}}, analysis_type) when status >= 400 do
    %{
      analysis_type: analysis_type,
      status: :error,
      error: "HTTP error: #{status}",
      error_code: "http_#{status}"
    }
  end

  def parse_analysis_response({:error, reason}, analysis_type) do
    %{
      analysis_type: analysis_type,
      status: :error,
      error: "Request failed: #{inspect(reason)}",
      error_code: "request_failure"
    }
  end

  defp transform_findings(api_findings, analysis_type) do
    Enum.map(api_findings, fn finding ->
      %{
        type: map_finding_type(finding["type"], analysis_type),
        severity: map_severity(finding["severity"]),
        message: finding["message"] || "No message provided",
        location: finding["location"],
        suggestion: finding["suggestion"],
        confidence: finding["confidence"] || 0.8,
        api_metadata: %{
          rule_id: finding["rule_id"],
          category: finding["category"]
        }
      }
    end)
  end

  defp map_finding_type(api_type, analysis_type) do
    case {api_type, analysis_type} do
      {"syntax_error", :code_analysis} -> :syntax_issue
      {"security_vulnerability", :security_analysis} -> :security_risk
      {"performance_issue", :performance_review} -> :performance
      {"anti_pattern", :pattern_detection} -> :anti_pattern
      {"missing_docs", :documentation} -> :documentation
      {"suggestion", :suggestion_engine} -> :suggestion
      {type, _} when is_binary(type) -> String.to_atom(type)
      _ -> :code_quality
    end
  end

  defp map_severity(api_severity) do
    case api_severity do
      "critical" -> :critical
      "high" -> :high
      "medium" -> :warning
      "low" -> :low
      "info" -> :info
      _ -> :info
    end
  end

  defp calculate_confidence_from_api(results) do
    # Extract confidence from API response or calculate based on findings
    case results["overall_confidence"] do
      confidence when is_number(confidence) -> confidence
      _ ->
        # Fallback calculation similar to existing mock implementation
        findings = results["findings"] || []
        critical_count = Enum.count(findings, & &1["severity"] == "critical")
        high_count = Enum.count(findings, & &1["severity"] == "high")

        base_confidence = 0.85
        penalty = (critical_count * 0.15) + (high_count * 0.10)
        max(0.5, base_confidence - penalty)
    end
  end
end
```

### 5. Error Handling and Fallback Strategies

#### 5.1 Fallback Mechanism

```elixir
defmodule Indrajaal.Validation.OpenCodeFallback do
  @moduledoc """
  Implements fallback strategies when OpenCode API is unavailable
  """

  def handle_api_failure(analysis_type, context, options, error_reason) do
    Logger.warn("OpenCode API failure: #{inspect(error_reason)}, falling back to simulation")

    case determine_fallback_strategy(error_reason) do
      :simulation_mode ->
        execute_simulation_fallback(analysis_type, context, options)

      :cached_response ->
        execute_cached_fallback(analysis_type, context, options)

      :minimal_validation ->
        execute_minimal_validation(analysis_type, context, options)

      :fail_fast ->
        {:error, "OpenCode API unavailable and no fallback configured"}
    end
  end

  defp determine_fallback_strategy(error_reason) do
    fallback_config = Application.get_env(:indrajaal, :opencode_fallback, :simulation_mode)

    case {error_reason, fallback_config} do
      {:rate_limited, _} -> :cached_response
      {:timeout, _} -> :minimal_validation
      {:network_error, :simulation_mode} -> :simulation_mode
      {:authentication_failed, _} -> :fail_fast
      {_, strategy} -> strategy
    end
  end

  defp execute_simulation_fallback(analysis_type, context, options) do
    # Use existing mock implementation as fallback
    Indrajaal.Validation.OpenCodeValidator.MockAnalysis.execute_single_analysis(
      %{session_id: options[:session_id]},
      analysis_type,
      context,
      options
    )
  end

  defp execute_cached_fallback(analysis_type, context, options) do
    # Look for similar cached results
    cache_key = generate_cache_key(analysis_type, context)

    case :ets.lookup(:opencode_cache, cache_key) do
      [{_, cached_result, timestamp}] when timestamp > System.system_time(:second) - 3600 ->
        Logger.info("Using cached OpenCode result for #{analysis_type}")
        cached_result

      _ ->
        execute_simulation_fallback(analysis_type, context, options)
    end
  end

  defp execute_minimal_validation(analysis_type, context, options) do
    # Return minimal findings with low confidence
    %{
      analysis_type: analysis_type,
      status: :completed,
      findings: [
        %{
          type: :system_limitation,
          severity: :warning,
          message: "OpenCode API unavailable - minimal validation performed"
        }
      ],
      confidence: 0.5,  # Low confidence due to limited analysis
      duration: 100,
      fallback_mode: :minimal_validation
    }
  end

  defp generate_cache_key(analysis_type, context) do
    content_hash = :crypto.hash(:sha256, get_in(context, [:code_context, :content]) || "")
                  |> Base.encode16()
                  |> String.slice(0, 16)

    "#{analysis_type}_#{content_hash}"
  end
end
```

### 6. Integration with Existing Pipeline

#### 6.1 Enhanced OpenCode Validator Module

```elixir
defmodule Indrajaal.Validation.OpenCodeValidatorLive do
  @moduledoc """
  Live OpenCode API integration for the Multi-AI Validation Framework
  Replaces mock implementation with real API calls while maintaining compatibility
  """

  alias Indrajaal.Validation.{OpenCodeClient, OpenCodeEndpoints, OpenCodeResponseParser, OpenCodeFallback}

  @api_mode Application.compile_env(:indrajaal, :opencode_api_mode, :live)  # :live, :simulation, :hybrid

  def execute_opencode_analysis(session, context, options) do
    analysis_types = Map.get(context, :analysis_types, [])
    Logger.info("🧠 Executing OpenCode analysis with #{length(analysis_types)} analysis types (mode: #{@api_mode})")

    case @api_mode do
      :live -> execute_live_analysis(session, analysis_types, context, options)
      :simulation -> execute_simulation_analysis(session, analysis_types, context, options)
      :hybrid -> execute_hybrid_analysis(session, analysis_types, context, options)
    end
  end

  defp execute_live_analysis(session, analysis_types, context, options) do
    analysis_results = Enum.map(analysis_types, fn analysis_type ->
      case execute_live_single_analysis(session, analysis_type, context, options) do
        {:ok, result} -> result
        {:error, reason} ->
          OpenCodeFallback.handle_api_failure(analysis_type, context, options, reason)
      end
    end)

    build_analysis_result(session, analysis_results, context)
  end

  defp execute_live_single_analysis(session, analysis_type, context, options) do
    # Check rate limiting
    case Indrajaal.Validation.OpenCodeRateLimit.check_rate_limit(session.session_id) do
      :ok ->
        make_api_request(analysis_type, context, options)
      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  defp make_api_request(analysis_type, context, options) do
    endpoint = OpenCodeEndpoints.get_endpoint(analysis_type)
    payload = OpenCodeEndpoints.build_request_payload(analysis_type, context, options)

    Logger.info("🌐 Making OpenCode API request: #{analysis_type} -> #{endpoint}")

    case OpenCodeClient.post(endpoint, payload) do
      response ->
        parsed = OpenCodeResponseParser.parse_analysis_response(response, analysis_type)

        # Cache successful responses
        if parsed.status == :completed do
          cache_response(analysis_type, context, parsed)
        end

        {:ok, parsed}
    end
  rescue
    error ->
      Logger.error("🚨 OpenCode API request failed: #{inspect(error)}")
      {:error, {:exception, error}}
  end

  defp cache_response(analysis_type, context, result) do
    cache_key = OpenCodeFallback.generate_cache_key(analysis_type, context)
    timestamp = System.system_time(:second)
    :ets.insert(:opencode_cache, {cache_key, result, timestamp})
  end

  defp execute_hybrid_analysis(session, analysis_types, context, options) do
    # Use API for critical analysis types, simulation for others
    critical_types = [:security_analysis, :pattern_detection]

    {critical_analyses, standard_analyses} = Enum.split_with(analysis_types, &(&1 in critical_types))

    # Execute critical analyses with API
    critical_results = Enum.map(critical_analyses, fn analysis_type ->
      case execute_live_single_analysis(session, analysis_type, context, options) do
        {:ok, result} -> result
        {:error, reason} ->
          OpenCodeFallback.handle_api_failure(analysis_type, context, options, reason)
      end
    end)

    # Execute standard analyses with simulation
    standard_results = Enum.map(standard_analyses, fn analysis_type ->
      OpenCodeFallback.execute_simulation_fallback(analysis_type, context, options)
    end)

    all_results = critical_results ++ standard_results
    build_analysis_result(session, all_results, context)
  end

  defp build_analysis_result(session, analysis_results, context) do
    %{
      status: :completed,
      session_id: session.session_id,
      analysis_results: analysis_results,
      total_duration: Enum.sum(Enum.map(analysis_results, & &1.duration)),
      findings_summary: aggregate_findings(analysis_results),
      api_mode: @api_mode,
      timestamp: DateTime.utc_now()
    }
  end

  # Reuse existing aggregate_findings function from mock implementation
  defp aggregate_findings(analysis_results) do
    total_findings = analysis_results
                    |> Enum.map(& length(&1.findings || []))
                    |> Enum.sum()

    avg_confidence = analysis_results
                    |> Enum.map(& &1.confidence)
                    |> Enum.sum()
                    |> Kernel./(length(analysis_results))

    %{
      total_findings: total_findings,
      average_confidence: avg_confidence,
      analysis_types_completed: length(analysis_results)
    }
  end
end
```

### 7. Configuration Management

#### 7.1 Application Configuration

```elixir
# config/config.exs
config :indrajaal,
  opencode_api_url: "https://api.opencode.ai",
  opencode_api_mode: :hybrid,  # :live, :simulation, :hybrid
  opencode_fallback: :simulation_mode,  # :simulation_mode, :cached_response, :minimal_validation, :fail_fast
  opencode_cache_ttl: 3600,  # 1 hour
  opencode_rate_limit: %{
    requests_per_minute: 100,
    burst_limit: 10
  }

# config/dev.exs
config :indrajaal,
  opencode_api_mode: :hybrid,
  opencode_api_url: "https://staging-api.opencode.ai"

# config/prod.exs
config :indrajaal,
  opencode_api_mode: :live,
  opencode_api_url: "https://api.opencode.ai"

# config/test.exs
config :indrajaal,
  opencode_api_mode: :simulation
```

#### 7.2 Runtime Configuration

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  opencode_api_key = System.get_env("OPENCODE_API_KEY")
  opencode_api_secret = System.get_env("OPENCODE_API_SECRET")

  if is_nil(opencode_api_key) or is_nil(opencode_api_secret) do
    raise """
    OpenCode API credentials not found!
    Set OPENCODE_API_KEY and OPENCODE_API_SECRET environment variables.
    """
  end

  config :indrajaal,
    opencode_api_key: opencode_api_key,
    opencode_api_secret: opencode_api_secret
end
```

### 8. Testing Strategy

#### 8.1 Unit Tests

```elixir
defmodule Indrajaal.Validation.OpenCodeValidatorLiveTest do
  use ExUnit.Case, async: true
  import Tesla.Mock

  setup do
    # Mock Tesla for HTTP requests
    mock(fn
      %{method: :post, url: "https://api.opencode.ai/v1/analyze/code"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "status" => "success",
            "results" => %{
              "findings" => [
                %{
                  "type" => "syntax_error",
                  "severity" => "high",
                  "message" => "Missing semicolon",
                  "location" => %{"line" => 10, "column" => 25}
                }
              ],
              "overall_confidence" => 0.85,
              "processing_time_ms" => 1500
            }
          }
        }

      %{method: :post, url: "https://api.opencode.ai/v1/auth/token"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "token" => "test_token_123",
            "expires_in" => 3600
          }
        }
    end)

    :ok
  end

  test "successfully executes live analysis" do
    session = %{session_id: "test_session_123"}
    context = %{
      analysis_types: [:code_analysis],
      code_context: %{content: "def test_function, do: :ok", extension: ".ex"}
    }
    options = %{session_id: "test_session_123"}

    result = Indrajaal.Validation.OpenCodeValidatorLive.execute_opencode_analysis(session, context, options)

    assert result.status == :completed
    assert length(result.analysis_results) == 1
    assert hd(result.analysis_results).analysis_type == :code_analysis
  end

  test "falls back to simulation on API failure" do
    # Test fallback mechanisms
    # Implementation would test various failure scenarios
  end
end
```

#### 8.2 Integration Tests

```elixir
defmodule Indrajaal.Validation.OpenCodeIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  test "end-to-end validation with live OpenCode API" do
    # Skip if API credentials not available
    unless System.get_env("OPENCODE_API_KEY") do
      ExUnit.skip("OpenCode API credentials not configured")
    end

    # Test complete validation pipeline
    result = Indrajaal.Validation.OpenCodeValidator.main([
      "--validate",
      "--analysis-type", "comprehensive",
      "--code-path", "test/fixtures/sample_code.ex",
      "--save-report"
    ])

    assert result == :ok
  end
end
```

### 9. Monitoring and Observability

#### 9.1 Telemetry Integration

```elixir
defmodule Indrajaal.Validation.OpenCodeTelemetry do
  @moduledoc """
  Telemetry integration for OpenCode API monitoring
  """

  def attach_handlers do
    :telemetry.attach_many(
      "opencode-telemetry",
      [
        [:opencode, :api, :request, :start],
        [:opencode, :api, :request, :stop],
        [:opencode, :api, :request, :exception],
        [:opencode, :analysis, :complete],
        [:opencode, :fallback, :activated]
      ],
      &handle_event/4,
      nil
    )
  end

  def handle_event([:opencode, :api, :request, :start], measurements, metadata, _config) do
    Logger.info("🌐 OpenCode API request started: #{metadata.analysis_type}")
  end

  def handle_event([:opencode, :api, :request, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("✅ OpenCode API request completed in #{duration_ms}ms: #{metadata.analysis_type}")

    # Send metrics to monitoring system
    :telemetry.execute([:indrajaal, :opencode, :request_duration], %{duration: duration_ms}, metadata)
  end

  def handle_event([:opencode, :api, :request, :exception], measurements, metadata, _config) do
    Logger.error("🚨 OpenCode API request failed: #{metadata.analysis_type} - #{inspect(metadata.reason)}")

    # Track error metrics
    :telemetry.execute([:indrajaal, :opencode, :request_error], %{count: 1}, metadata)
  end

  def handle_event([:opencode, :analysis, :complete], measurements, metadata, _config) do
    Logger.info("📊 OpenCode analysis complete: confidence=#{metadata.confidence}")
  end

  def handle_event([:opencode, :fallback, :activated], measurements, metadata, _config) do
    Logger.warn("⚠️ OpenCode fallback activated: #{metadata.fallback_strategy}")

    # Track fallback usage
    :telemetry.execute([:indrajaal, :opencode, :fallback], %{count: 1}, metadata)
  end
end
```

## Implementation Timeline

### Phase 1: Core Infrastructure (Week 1)
- [ ] Implement Tesla client with authentication
- [ ] Set up rate limiting and caching
- [ ] Create response parser and error handling
- [ ] Unit tests for core components

### Phase 2: API Integration (Week 2)
- [ ] Implement live analysis execution
- [ ] Set up fallback mechanisms
- [ ] Integration with existing validation pipeline
- [ ] Environment configuration

### Phase 3: Testing and Validation (Week 3)
- [ ] Comprehensive test suite
- [ ] Integration testing with staging API
- [ ] Performance testing and optimization
- [ ] Documentation and deployment guides

### Phase 4: Production Deployment (Week 4)
- [ ] Production configuration
- [ ] Monitoring and alerting setup
- [ ] Gradual rollout with feature flags
- [ ] Post-deployment validation

## Risk Mitigation

### High-Risk Areas
1. **API Availability**: Comprehensive fallback to simulation mode
2. **Rate Limiting**: Intelligent request distribution and caching
3. **Authentication**: Token refresh with proper error handling
4. **Response Format Changes**: Robust parsing with backward compatibility
5. **Performance Impact**: Asynchronous processing and timeouts

### Monitoring Requirements
- API response time and success rate metrics
- Authentication failure tracking
- Fallback activation frequency
- Consensus impact analysis
- Error rate monitoring

## Conclusion

This architecture provides a robust foundation for integrating live OpenCode API functionality while maintaining the reliability and EP-110 prevention capabilities of the existing mock implementation. The hybrid approach allows for gradual adoption and provides comprehensive fallback mechanisms to ensure system reliability.

The design preserves the existing 30% weight in the multi-AI consensus system and maintains compatibility with the current validation pipeline, ensuring seamless integration with Claude (40%) and FPPS (30%) validators.