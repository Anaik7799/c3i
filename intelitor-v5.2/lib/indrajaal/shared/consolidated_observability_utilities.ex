defmodule Indrajaal.Shared.ConsolidatedObservabilityUtilities do
  @moduledoc """
  Consolidated Observability Utilities - Eliminates duplicate observability patterns

  Combines functionality from multiple observability helper modules.
  """

  @doc """
  Format trace ID consistently across all modules.
  """
  @spec format_trace_id(binary() | integer()) :: term()
  def format_trace_id(trace_id) when is_integer(trace_id) do
    trace_id |> Integer.to_string(16) |> String.pad_leading(32, "0")
  end

  @spec format_trace_id(binary() | integer()) :: term()
  def format_trace_id(trace_id) when is_binary(trace_id), do: trace_id
  @spec format_trace_id(term()) :: term()
  # def format_trace_id(_), do: "unknown"
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Format span ID consistently across all modules.
  """
  @spec format_span_id(binary() | integer()) :: term()
  def format_span_id(span_id) when is_integer(span_id) do
    span_id |> Integer.to_string(16) |> String.pad_leading(16, "0")
  end

  @spec format_span_id(binary() | integer()) :: term()
  def format_span_id(span_id) when is_binary(span_id), do: span_id
  @spec format_span_id(term()) :: term()
  # def format_span_id(_), do: "unknown"
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Add span attributes with consistent formatting.
  """
  @spec add_span_attributes(term()) :: term()
  def add_span_attributes(attributes) when is_map(attributes) do
    if Code.ensure_loaded?(OpenTelemetry) do
      formatted_attrs =
        attributes
        |> Enum.map(fn {key, value} ->
          {to_string(key), format_attribute_value(value)}
        end)

      OpenTelemetry.Tracer.set_attributes(formatted_attrs)
    end
  end

  defp format_attribute_value(value) when is_binary(value), do: value
  defp format_attribute_value(value) when is_number(value), do: value
  defp format_attribute_value(value), do: inspect(value)
end
