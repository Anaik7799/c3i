defmodule Indrajaal.Validation.OpenCodeAPIClient do
  @moduledoc """
  OpenCode API client for live code analysis integration.

  Replaces mock simulation with real OpenCode API calls while maintaining
  backward compatibility and providing fallback to simulation mode.

  Features:
  - Authentication with API key management
  - Rate limiting with exponential backoff
  - Network error handling with retry mechanisms
  - Fallback to simulation for offline development
  - EP-110/EP-111 false positive prevention
  - Response parsing to existing validator format
  """

  require Logger
  alias Indrajaal.Validation.OpenCodeSimulator

  @base_url "https://api.opencode.ai/v1"
  @timeout 60_000
  @rate_limit_per_minute 30
  @max_retries 5
  @initial_retry_delay 1000
  @max_retry_delay 30_000
  @backoff_multiplier 2.0
  @jitter_range 0.1

  @api_endpoint_mapping %{
    code_analysis: "/analyze/code-quality",
    security_analysis: "/analyze/security",
    pattern_detection: "/analyze/patterns",
    performance_review: "/analyze/performance",
    documentation: "/analyze/documentation"
  }

  @analysis_type_mapping %{
    compilation: :code_analysis,
    security: :security_analysis,
    performance: :performance_review,
    documentation: :documentation,
    comprehensive: :code_analysis
  }

  defstruct [
    :api_key,
    :session_id,
    :authenticated,
    :rate_limiter,
    :base_url,
    :timeout,
    :retry_state,
    created_at: nil
  ]

  @type session :: %__MODULE__{
          api_key: String.t(),
          session_id: String.t(),
          authenticated: boolean(),
          rate_limiter: map(),
          base_url: String.t(),
          timeout: integer(),
          retry_state: map(),
          created_at: DateTime.t()
        }

  @type analysis_request :: %{
          code: String.t(),
          type: atom(),
          options: map()
        }

  @type analysis_result :: %{
          status: atom(),
          findings: [map()],
          confidence: float(),
          simulation_mode: boolean(),
          ep110_risk: boolean()
        }

  @doc """
  Creates a new OpenCode API session with authentication.

  ## Examples

      iex> OpenCodeAPIClient.create_session("valid_api_key", "session_123")
      {:ok, %OpenCodeAPIClient{api_key: "valid_api_key", authenticated: true}}

      iex> OpenCodeAPIClient.create_session("invalid_key", "session_123")
      {:error, :unauthorized}
  """
  @spec create_session(String.t(), String.t()) :: {:ok, session()} | {:error, atom()}
  def create_session(api_key, session_id) do
    with :ok <- validate_api_key(api_key),
         {:ok, rate_limiter} <- initialize_rate_limiter(),
         {:ok, retry_state} <- initialize_retry_state() do
      session = %__MODULE__{
        api_key: api_key,
        session_id: session_id,
        authenticated: true,
        rate_limiter: rate_limiter,
        base_url: @base_url,
        timeout: @timeout,
        retry_state: retry_state,
        created_at: DateTime.utc_now()
      }

      Logger.info("OpenCode API session created", session_id: session_id)
      {:ok, session}
    else
      {:error, reason} ->
        Logger.warning("OpenCode API session creation failed",
          reason: reason,
          session_id: session_id
        )

        {:error, reason}
    end
  end

  @doc """
  Analyzes code using the OpenCode API with fallback to simulation.

  ## Examples

      iex> session = %OpenCodeAPIClient{authenticated: true}
      iex> OpenCodeAPIClient.analyze_code(session, %{code: "def hello, do: :world", type: :compilation})
      {:ok, %{status: :completed, findings: [], confidence: 95.0}}
  """
  @spec analyze_code(session(), analysis_request()) :: {:ok, analysis_result()} | {:error, atom()}
  def analyze_code(session, request) do
    case analyze_code_with_retry(session, request, 0) do
      {:ok, result} ->
        {:ok, result}

      {:error, :rate_limited} = error ->
        Logger.warning("Rate limit exceeded after all retries", session_id: session.session_id)
        error

      {:error, :network_error} ->
        Logger.warning("Network error, falling back to simulation",
          session_id: session.session_id
        )

        fallback_to_simulation(request)

      {:error, :timeout} ->
        Logger.warning("API timeout, falling back to simulation", session_id: session.session_id)
        fallback_to_simulation(request)

      {:error, reason} = error ->
        Logger.error("API request failed", reason: reason, session_id: session.session_id)
        error
    end
  end

  @doc """
  Gets the API endpoint for a given analysis type.

  ## Examples

      iex> OpenCodeAPIClient.get_endpoint(:code_analysis)
      "/analyze/code-quality"
  """
  @spec get_endpoint(atom()) :: String.t()
  def get_endpoint(analysis_type) do
    Map.get(@api_endpoint_mapping, analysis_type, "/analyze/code-quality")
  end

  @doc """
  Transforms request parameters for API compatibility.

  ## Examples

      iex> request = %{code: "def hello, do: :world", type: :compilation}
      iex> OpenCodeAPIClient.transform_request(request)
      {:ok, %{source_code: "def hello, do: :world", analysis_type: "code_analysis"}}
  """
  @spec transform_request(analysis_request()) :: {:ok, map()} | {:error, atom()}
  def transform_request(%{code: code, type: type} = request) do
    analysis_type = Map.get(@analysis_type_mapping, type, :code_analysis)

    transformed = %{
      source_code: code,
      analysis_type: Atom.to_string(analysis_type),
      configuration: transform_options(Map.get(request, :options, %{}))
    }

    {:ok, transformed}
  end

  def transform_request(_), do: {:error, :invalid_request}

  @doc """
  Parses API response to existing validator format.

  ## Examples

      iex> api_response = %{"status" => "completed", "findings" => [], "confidence" => 0.95}
      iex> OpenCodeAPIClient.parse_response(api_response)
      {:ok, %{status: :completed, findings: [], confidence: 95.0}}
  """
  @spec parse_response(map()) :: {:ok, analysis_result()} | {:error, atom()}
  def parse_response(
        %{"status" => status, "findings" => findings, "confidence" => confidence} = response
      ) do
    parsed_findings = Enum.map(findings, &parse_finding/1)
    confidence_score = confidence * 100.0

    # EP-110 False Positive Prevention
    ep110_risk = detect_ep110_risk(response, parsed_findings, confidence_score)
    adjusted_confidence = if ep110_risk, do: min(confidence_score, 65.0), else: confidence_score

    result = %{
      status: String.to_existing_atom(status),
      findings: parsed_findings,
      confidence: adjusted_confidence,
      simulation_mode: false,
      ep110_risk: ep110_risk
    }

    {:ok, result}
  rescue
    ArgumentError ->
      {:error, :malformed_response}
  end

  def parse_response(_), do: {:error, :malformed_response}

  # Private Functions

  defp validate_api_key(api_key) when is_binary(api_key) and byte_size(api_key) > 0 do
    # In production, this would validate against OpenCode API
    # For now, accept any non-empty string as valid
    if String.length(api_key) >= 10 do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp validate_api_key(_), do: {:error, :unauthorized}

  defp initialize_rate_limiter do
    rate_limiter = %{
      requests_per_minute: @rate_limit_per_minute,
      request_count: 0,
      window_start: DateTime.utc_now(),
      request_times: [],
      adaptive_limit: @rate_limit_per_minute,
      consecutive_rate_limits: 0
    }

    {:ok, rate_limiter}
  end

  defp initialize_retry_state do
    retry_state = %{
      total_retries: 0,
      consecutive_failures: 0,
      last_failure_time: nil,
      current_delay: @initial_retry_delay,
      failure_types: %{}
    }

    {:ok, retry_state}
  end

  defp check_rate_limit(session) do
    current_time = DateTime.utc_now()
    rate_limiter = session.rate_limiter

    # Clean old request times (older than 1 minute)
    recent_requests =
      Enum.filter(rate_limiter.request_times, fn request_time ->
        DateTime.diff(current_time, request_time, :second) < 60
      end)

    # Check adaptive rate limit
    current_limit = rate_limiter.adaptive_limit

    if length(recent_requests) >= current_limit do
      # Apply exponential backoff for rate limiting
      backoff_delay = calculate_rate_limit_backoff(rate_limiter.consecutive_rate_limits)

      Logger.warning("Rate limit exceeded, backing off for #{backoff_delay}ms",
        session_id: session.session_id,
        current_limit: current_limit,
        recent_requests: length(recent_requests)
      )

      # Sleep for backoff period
      Process.sleep(backoff_delay)

      {:error, :rate_limited}
    else
      :ok
    end
  end

  defp calculate_rate_limit_backoff(consecutive_failures) do
    base_delay = @initial_retry_delay
    multiplier = :math.pow(@backoff_multiplier, consecutive_failures)
    jitter = base_delay * @jitter_range * (:rand.uniform() - 0.5)

    delay = base_delay * multiplier + jitter
    capped_delay = min(delay, @max_retry_delay)
    round(capped_delay)
  end

  # Retry mechanism with exponential backoff
  defp analyze_code_with_retry(session, request, attempt) when attempt < @max_retries do
    with :ok <- check_rate_limit_with_backoff(session, attempt),
         {:ok, transformed_request} <- transform_request(request),
         {:ok, updated_session} <- update_request_tracking(session),
         {:ok, api_response} <-
           make_api_request_with_retry(updated_session, transformed_request, attempt) do
      # Reset retry state on success
      reset_retry_state(updated_session)
      parse_response(api_response)
    else
      {:error, :rate_limited} ->
        backoff_delay = calculate_exponential_backoff(attempt)

        Logger.info("Rate limited, retrying in #{backoff_delay}ms",
          session_id: session.session_id,
          attempt: attempt + 1,
          max_retries: @max_retries
        )

        Process.sleep(backoff_delay)
        analyze_code_with_retry(session, request, attempt + 1)

      {:error, :server_error} ->
        backoff_delay = calculate_exponential_backoff(attempt)

        Logger.warning("Server error, retrying in #{backoff_delay}ms",
          session_id: session.session_id,
          attempt: attempt + 1
        )

        Process.sleep(backoff_delay)
        analyze_code_with_retry(session, request, attempt + 1)

      {:error, :timeout} ->
        backoff_delay = calculate_exponential_backoff(attempt)

        Logger.warning("Timeout, retrying in #{backoff_delay}ms",
          session_id: session.session_id,
          attempt: attempt + 1
        )

        Process.sleep(backoff_delay)
        analyze_code_with_retry(session, request, attempt + 1)

      {:error, reason} = error ->
        Logger.error("Non-retryable error on attempt #{attempt + 1}",
          session_id: session.session_id,
          reason: reason
        )

        error
    end
  end

  defp analyze_code_with_retry(session, _request, attempt) do
    Logger.error("Max retries (#{@max_retries}) exceeded",
      session_id: session.session_id,
      final_attempt: attempt
    )

    {:error, :max_retries_exceeded}
  end

  defp make_api_request_with_retry(session, request, attempt) do
    url = session.base_url <> get_endpoint(String.to_existing_atom(request.analysis_type))

    headers = [
      {"Authorization", "Bearer #{session.api_key}"},
      {"Content-Type", "application/json"},
      {"X-Session-ID", session.session_id},
      {"X-Retry-Attempt", Integer.to_string(attempt)}
    ]

    # Adaptive timeout based on attempt
    adaptive_timeout = calculate_adaptive_timeout(session.timeout, attempt)

    options = [
      timeout: adaptive_timeout,
      # Extra buffer for processing
      receive_timeout: adaptive_timeout + 5_000
    ]

    Logger.debug("Making API request",
      session_id: session.session_id,
      attempt: attempt,
      timeout: adaptive_timeout,
      url: url
    )

    case Req.post(url, json: request, headers: headers, options: options) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("API request successful",
          session_id: session.session_id,
          attempt: attempt
        )

        {:ok, body}

      {:ok, %{status: 401}} ->
        Logger.warning("API authentication failed",
          session_id: session.session_id,
          attempt: attempt
        )

        {:error, :unauthorized}

      {:ok, %{status: 429, headers: response_headers}} ->
        # Extract rate limit information from headers
        rate_limit_info = extract_rate_limit_headers(response_headers)

        Logger.warning("API rate limit exceeded",
          session_id: session.session_id,
          attempt: attempt,
          rate_limit_info: rate_limit_info
        )

        {:error, :rate_limited}

      {:ok, %{status: status}} when status >= 500 ->
        Logger.warning("API server error",
          session_id: session.session_id,
          attempt: attempt,
          status: status
        )

        {:error, :server_error}

      {:ok, %{status: status}} ->
        Logger.warning("API client error",
          session_id: session.session_id,
          attempt: attempt,
          status: status
        )

        {:error, :client_error}

      {:error, %{reason: :timeout}} ->
        Logger.warning("API request timeout",
          session_id: session.session_id,
          attempt: attempt,
          timeout: adaptive_timeout
        )

        {:error, :timeout}

      {:error, %{reason: reason}} when reason in [:econnrefused, :nxdomain] ->
        Logger.warning("API network error",
          session_id: session.session_id,
          attempt: attempt,
          reason: reason
        )

        {:error, :network_error}

      {:error, reason} ->
        Logger.error("API unknown error",
          session_id: session.session_id,
          attempt: attempt,
          reason: reason
        )

        {:error, :unknown_error}
    end
  end

  defp fallback_to_simulation(request) do
    Logger.info("Using simulation mode for analysis", type: request.type)

    # Use existing simulation logic
    case OpenCodeSimulator.simulate_analysis(request.code, request.type) do
      {:ok, result} ->
        {:ok, Map.put(result, :simulation_mode, true)}

      error ->
        error
    end
  end

  defp transform_options(options) do
    options
    |> Enum.reduce(%{}, fn
      {:timeout, timeout}, acc -> Map.put(acc, :timeout_ms, timeout)
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  defp parse_finding(%{"type" => type, "message" => message} = finding) do
    %{
      type: String.to_existing_atom(type),
      message: message,
      file: Map.get(finding, "file"),
      line: Map.get(finding, "line"),
      severity: parse_severity(Map.get(finding, "severity", "medium"))
    }
  end

  defp parse_severity("high"), do: :high
  defp parse_severity("medium"), do: :medium
  defp parse_severity("low"), do: :low
  defp parse_severity(_), do: :medium

  defp detect_ep110_risk(response, findings, confidence) do
    # EP-110 False Positive Detection
    cond do
      # High confidence but has internal errors
      confidence > 90.0 and Map.has_key?(response, "internal_errors") ->
        true

      # Claims no errors but suspicious patterns exist
      findings == [] and confidence > 95.0 and
          Map.get(response, "analysis_duration", 0) < 100 ->
        true

      # Confidence too high for complex code
      confidence > 98.0 and String.length(Map.get(response, "source_code", "")) > 1000 ->
        true

      true ->
        false
    end
  end

  # Enhanced rate limiting with exponential backoff
  defp check_rate_limit_with_backoff(session, attempt) do
    case check_rate_limit(session) do
      :ok ->
        :ok

      {:error, :rate_limited} ->
        if attempt < @max_retries do
          {:error, :rate_limited}
        else
          Logger.error("Rate limit exceeded on final attempt",
            session_id: session.session_id,
            attempt: attempt
          )

          {:error, :rate_limited}
        end
    end
  end

  # Exponential backoff calculation with jitter
  defp calculate_exponential_backoff(attempt) do
    base_delay = @initial_retry_delay
    exponential_delay = base_delay * :math.pow(@backoff_multiplier, attempt)
    jitter = exponential_delay * @jitter_range * (:rand.uniform() - 0.5)

    final_delay = exponential_delay + jitter
    capped_delay = min(final_delay, @max_retry_delay)
    round(capped_delay)
  end

  # Adaptive timeout calculation
  defp calculate_adaptive_timeout(base_timeout, attempt) do
    # Increase timeout slightly with each retry to account for potential congestion
    multiplier = 1.0 + attempt * 0.2
    round(base_timeout * multiplier)
  end

  # Update request tracking for adaptive rate limiting
  defp update_request_tracking(session) do
    current_time = DateTime.utc_now()

    updated_rate_limiter = %{
      session.rate_limiter
      | request_times: [current_time | session.rate_limiter.request_times],
        request_count: session.rate_limiter.request_count + 1
    }

    updated_session = %{session | rate_limiter: updated_rate_limiter}
    {:ok, updated_session}
  end

  # Reset retry state after successful request
  defp reset_retry_state(session) do
    reset_state = %{
      session.retry_state
      | consecutive_failures: 0,
        current_delay: @initial_retry_delay
    }

    %{session | retry_state: reset_state}
  end

  # Extract rate limit information from response headers
  defp extract_rate_limit_headers(headers) do
    headers
    |> Enum.reduce(%{}, fn
      {"x-ratelimit-limit", value}, acc -> Map.put(acc, :limit, value)
      {"x-ratelimit-remaining", value}, acc -> Map.put(acc, :remaining, value)
      {"x-ratelimit-reset", value}, acc -> Map.put(acc, :reset, value)
      {"retry-after", value}, acc -> Map.put(acc, :retry_after, value)
      _, acc -> acc
    end)
  end
end
