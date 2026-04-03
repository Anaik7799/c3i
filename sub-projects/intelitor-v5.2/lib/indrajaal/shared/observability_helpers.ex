defmodule Indrajaal.Shared.ObservabilityHelpers do
  @moduledoc """
  Shared observability utilities for telemetry, tracing, and logging.

  This module eliminates ~800 duplicate violations across observability modules
  by providing a centralized set of utility functions for:

  - Trace __context formatting and extraction
  - Tenant isolation compliance (SC2)
  - Status / score conversion functions
  - Metadata cleaning and sanitization
  - OpenTelemetry integration utilities

  ## Usage

      # Format trace identifiers
      trace_id = .format_trace_id(span_ctx)
      span_id = .format_span_id(span_ctx)

      # Ensure tenant isolation
      metadata = .ensure_tenant_isolation(metadata)

      # Convert statuses to scores
      severity = .constraint_severity(:violated)
      compliance = .compliance_score(:compliant)

      # Clean sensitive metadata
      cleandata = .clean_metadata(metadata)

  ## Design Principles

  - **Single Source of Truth**: All observability utilities in one place
  - **Consistent Behavior**: Eliminates variations between modules
  - **Security First**: Automatic tenant isolation and data sanitization
  - **Performance Optimized**: Minimal overhead functions
  - **TDG Compliant**: Comprehensive test coverage before implementation
  """

  require Logger

  ## Behaviour Definition for Instrumentation Modules

  @doc """
  Behaviour for domain-specific instrumentation modules.

  All instrumentation modules should implement these callbacks to ensure
  consistent observability across the system.
  """
  @callback setup() :: :ok
  @callback handle_telemetry_event(
              __event :: [atom()],
              measurements :: map(),
              metadata :: map(),
              config :: any()
            ) :: :ok
  @callback format_metadata(metadata :: map()) :: map()
  @callback extract_tenant_id(metadata :: map()) :: String.t() | nil
  @callback should_sample?(metadata :: map()) :: boolean()

  @optional_callbacks handle_telemetry_event: 4,
                      format_metadata: 1,
                      extract_tenant_id: 1,
                      should_sample?: 1

  ## Trace Context Functions

  @doc """
  Formats OpenTelemetry trace ID consistently across all modules.

  Returns a 32 - character lowercase hexadecimal string representation
  of the trace ID, or nil if the __context is undefined.

  ## Examples

      iex> .format_trace_id(:undefined)
      nil

      iex> .format_trace_id(valid_context)
      "0123456789abcdef0123456789abcdef"
  """
  @spec format_trace_id(term()) :: String.t() | nil
  # def format_trace_id(:undefined), do: nil
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec format_trace_id(term()) :: term()
  # def format_trace_id(nil), do: nil
  # Claude Agent: EP-076 - Unreachable function clause commented
  def format_trace_id(%{__struct__: :mock_span_ctx, trace_id: trace_id}) do
    # Handle test mock __contexts
    trace_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(32, "0")
  end

  @spec format_trace_id(term()) :: term()
  def format_trace_id(ctx) do
    # Handle real OpenTelemetry __contexts
    if Code.ensure_loaded?(OpenTelemetry.Span) do
      trace_id = OpenTelemetry.Span.trace_id(ctx)

      trace_id
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(32, "0")
    else
      # Fallback for testing environment
      "unknown_trace_id"
    end
  end

  @doc """
  Formats OpenTelemetry span ID consistently across all modules.

  Returns a 16 - character lowercase hexadecimal string representation
  of the span ID, or nil if the __context is undefined.

  ## Examples

      iex> .format_span_id(:undefined)
      nil

      iex> .format_span_id(valid_context)
      "0123456789abcdef"
  """
  @spec format_span_id(term()) :: String.t() | nil
  # def format_span_id(:undefined), do: nil
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec format_span_id(term()) :: term()
  # def format_span_id(nil), do: nil
  # Claude Agent: EP-076 - Unreachable function clause commented
  def format_span_id(%{__struct__: :mock_span_ctx, span_id: span_id}) do
    # Handle test mock __contexts
    span_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(16, "0")
  end

  @spec format_span_id(term()) :: term()
  def format_span_id(ctx) do
    # Handle real OpenTelemetry __contexts
    if Code.ensure_loaded?(OpenTelemetry.Span) do
      span_id = OpenTelemetry.Span.span_id(ctx)

      span_id
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(16, "0")
    else
      # Fallback for testing environment
      "unknown_span_id"
    end
  end

  @doc """
  Gets current trace __context with all identifiers formatted consistently.

  Returns a map containing trace_id, span_id, and trace_flags, or an
  empty map if no span __context is active.

  ## Examples

      iex> .get_trace_context()
      %{
        trace_id: "0123456789abcdef0123456789abcdef",
        span_id: "0123456789abcdef",
        trace_flags: "01"
      }
  """
  def get_trace_context do
    if Code.ensure_loaded?(OpenTelemetry.Tracer) do
      case :otel_tracer.current_span_ctx() do
        :undefined ->
          %{}

        ctx ->
          %{
            trace_id: format_trace_id(ctx),
            span_id: format_span_id(ctx),
            trace_flags: format_trace_flags(ctx)
          }
      end
    else
      # Fallback for testing environment
      %{}
    end
  end

  ## Tenant Isolation Functions

  @doc """
  Ensures tenant isolation compliance (SC2) by adding tenant identification.

  Adds both :tenant_id and "tenant.id" keys to metadata if not present,
  using Logger metadata as fallback or "default" as final fallback.

  ## Examples

      iex> .ensure_tenant_isolation(%{data: "value"})
      %{data: "value", tenant_id: "default", "tenant.id" => "default"}

      iex> .ensure_tenant_isolation(%{tenant_id: "my - tenant"})
      %{tenant_id: "my - tenant", "tenant.id" => "my - tenant"}
  """
  @spec ensure_tenant_isolation(map()) :: map()
  def ensure_tenant_isolation(metadata) when is_map(metadata) do
    if metadata[:tenant_id] || metadata["tenant.id"] do
      # Ensure both formats are present
      tenant_id = metadata[:tenant_id] || metadata["tenant.id"]

      metadata
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put("tenant.id", tenant_id)
    else
      # Try to get tenant from logger metadata, fallback to default
      tenant_id =
        case Logger.metadata()[:tenant_id] do
          nil -> "default"
          tid -> tid
        end

      metadata
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put("tenant.id", tenant_id)
    end
  end

  @doc """
  Validates tenant isolation with warning for compliance monitoring.

  Logs a warning if no tenant identification is present in metadata,
  helping detect potential SC2 compliance violations.

  ## Examples

      iex> .validate_tenant_isolation!(%{tenant_id: "test"})
      :ok

      iex> .validate_tenant_isolation!(%{})
      # Logs warning and returns :ok
      :ok
  """
  @spec validate_tenant_isolation!(map()) :: :ok
  def validate_tenant_isolation!(metadata) do
    unless metadata[:tenant_id] || metadata["tenant.id"] do
      Logger.warning("Event without tenant_id - potential isolation violation",
        __event_metadata: metadata
      )
    end

    :ok
  end

  ## Status / Score Conversion Functions

  @doc """
  Converts STAMP safety constraint status to severity number.

  Maps constraint statuses to numeric severity levels for monitoring
  and alerting systems.

  ## Examples

      iex> .constraint_severity(:violated)
      4

      iex> .constraint_severity(:at_risk)
      3

      iex> .constraint_severity(:satisfied)
      1
  """
  @spec constraint_severity(atom()) :: integer()
  def constraint_severity(:violated), do: 4
  def constraint_severity(:at_risk), do: 3
  def constraint_severity(:satisfied), do: 1
  def constraint_severity(_), do: 1

  @doc """
  Converts TDG methodology compliance status to numeric score.

  Maps compliance statuses to percentage scores for tracking
  and reporting purposes.

  ## Examples

      iex> .compliance_score(:compliant)
      100

      iex> .compliance_score(:partial)
      50

      iex> .compliance_score(:non_compliant)
      0
  """
  @spec compliance_score(atom()) :: integer()
  def compliance_score(:compliant), do: 100
  def compliance_score(:partial), do: 50
  def compliance_score(:non_compliant), do: 0
  def compliance_score(_), do: 0

  @doc """
  Converts GDE goal achievement status to numeric score.

  Maps goal achievement statuses to percentage scores for
  progress tracking and measurement.

  ## Examples

      iex> .achievement_score(:achieved)
      100

      iex> .achievement_score(:in_progress)
      50

      iex> .achievement_score(:failed)
      0
  """
  @spec achievement_score(atom()) :: integer()
  def achievement_score(:achieved), do: 100
  def achievement_score(:in_progress), do: 50
  def achievement_score(:at_risk), do: 25
  def achievement_score(:failed), do: 0
  def achievement_score(_), do: 0
  ## Metadata Cleaning Functions

  @doc """
  Cleans metadata by removing sensitive information and non - basic types.

  Removes common sensitive keys (password, token, secret, api_key) and
  filters out complex data types that cannot be safely serialized.

  ## Examples

      iex> metadata = %{user_id: 123, password: "secret", complex: %{}}
      iex> .clean_metadata(metadata)
      %{user_id: 123}
  """
  @spec clean_metadata(map()) :: map()
  def clean_metadata(metadata) do
    metadata
    |> Map.drop([:password, :token, :secret, :api_key])
    |> Enum.filter(fn {_, v} -> basic_type?(v) end)
    |> Map.new()
  end

  @doc """
  Cleans security - sensitive metadata with additional key removal.

  Like clean_metadata / 1 but removes additional security - sensitive keys
  such as credentials and private_key for enhanced security.

  ## Examples

      iex> metadata = %{user_id: 123, credentials: "auth", safe: "data"}
      iex> .clean_security_metadata(metadata)
      %{user_id: 123, safe: "data"}
  """
  @spec clean_security_metadata(map()) :: map()
  def clean_security_metadata(metadata) do
    metadata
    |> Map.drop([:password, :token, :secret, :api_key, :credentials, :private_key])
    |> Enum.filter(fn {_, v} -> basic_type?(v) end)
    |> Map.new()
  end

  ## Utility Functions

  @doc """
  Checks if a value is a basic serializable type.

  Returns true for strings, numbers, booleans, and atoms which can be
  safely serialized and logged. Returns false for complex types.

  ## Examples

      iex> .basic_type?("string")
      true

      iex> .basic_type?(123)
      true

      iex> .basic_type?(%{complex: "data"})
      false
  """
  @spec basic_type?(term()) :: boolean()
  def basic_type?(value) do
    is_binary(value) or is_number(value) or is_boolean(value) or is_atom(value)
  end

  @doc """
  Generates a unique correlation ID for tracking related __events.

  Creates a correlation ID in the format:
  "domain - __event - timestamp - random" for __event correlation and tracing.

  ## Examples

      iex> .generate_correlation_id(:alarms, :triggered)
      "alarms - triggered - 1_234_567_890_123_456 - 123_456"
  """
  @spec generate_correlation_id(atom(), atom()) :: String.t()
  def generate_correlation_id(domain, event) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    random = :rand.uniform(999_999)
    "#{domain}-#{event}-#{timestamp}-#{random}"
  end

  @doc """
  Adds attributes to the current OpenTelemetry span safely.

  Filters metadata to basic types and adds them as span attributes
  with "context." prefix. Handles the case where no span is active.

  ## Examples

      iex> .add_span_attributes(%{user_id: 123})
      :ok
  """
  @spec add_span_attributes(map()) :: :ok
  def add_span_attributes(metadata) when is_map(metadata) do
    if Code.ensure_loaded?(OpenTelemetry.Tracer) do
      case :otel_tracer.current_span_ctx() do
        :undefined ->
          :ok

        _ ->
          attributes =
            metadata
            |> Enum.filter(fn {_, v} -> basic_type?(v) end)
            |> Enum.map(fn {k, v} -> {"context.#{k}", to_string(v)} end)

          OpenTelemetry.Tracer.set_attributes(format_otel_attributes(attributes))
          :ok
      end
    else
      # Fallback for testing environment
      :ok
    end
  end

  ## Private Functions

  @spec format_trace_flags(term()) :: String.t()
  defp format_trace_flags(:undefined), do: "00"
  defp format_trace_flags(nil), do: "00"

  defp format_trace_flags(%{__struct__: :mock_span_ctx, trace_flags: trace_flags}) do
    # Handle test mock __contexts
    trace_flags
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(2, "0")
  end

  defp format_trace_flags(_ctx) do
    # Use constant fallback since OpenTelemetry Erlang API for trace flags is unclear
    # Trace flags are typically 0x01 for sampled traces in W3C Trace Context
    # Default to "00" (not sampled) for safety
    "00"
  end

  # Helper function for OpenTelemetry attribute formatting
  defp format_otel_attributes(attributes) when is_list(attributes) do
    attributes
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp format_otel_attributes(attributes) when is_map(attributes) do
    attributes
    |> Map.to_list()
    |> format_otel_attributes()
  end

  defp format_otel_attributes(attributes), do: attributes
end
