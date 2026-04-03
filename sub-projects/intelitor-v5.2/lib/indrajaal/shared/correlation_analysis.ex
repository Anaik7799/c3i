defmodule Indrajaal.Shared.CorrelationAnalysis do
  @moduledoc """
  Shared utility functions for correlation analysis and trend calculations.

  This module provides reusable correlation analysis functionality to eliminate
  code duplication across testing analytics and other modules.
  """

  @doc """
  Interprets correlation coefficient to determine trend direction.

  ## Parameters
  - correlation: Decimal correlation coefficient

  ## Returns
  - :improving when correlation > 0.3
  - :degrading when correlation < -0.3
  - :stable for values between -0.3 and 0.3
  - :insufficient_data when correlation is nil

  ## Examples

      iex> Indrajaal.Shared.CorrelationAnalysis.interpret_correlation(Decimal.new("0.5"))
      :improving

      iex> Indrajaal.Shared.CorrelationAnalysis.interpret_correlation(Decimal.new("-0.5"))
      :degrading

      iex> Indrajaal.Shared.CorrelationAnalysis.interpret_correlation(Decimal.new("0.1"))
      :stable

      iex> Indrajaal.Shared.CorrelationAnalysis.interpret_correlation(nil)
      :insufficient_data
  """
  @spec interpret_correlation(Decimal.t() | nil) ::
          :improving | :degrading | :stable | :insufficient_data
  @spec interpret_correlation(term()) :: term()
  # def interpret_correlation(nil), do: :insufficient_data
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec interpret_correlation(term()) :: term()
  def interpret_correlation(correlation) when is_number(correlation) do
    cond do
      correlation > 0.3 -> :improving
      correlation < -0.3 -> :degrading
      true -> :stable
    end
  end

  # Handle Decimal struct if available at runtime
  @spec interpret_correlation(term()) :: term()
  def interpret_correlation(correlation) do
    case correlation do
      %{__struct__: module} ->
        # Check if module name ends with "Decimal"
        module_name = Atom.to_string(module)

        if String.ends_with?(module_name, "Decimal") do
          # Use dynamic call to handle Decimal module
          corr_val = module.to_float(correlation)
          interpret_correlation(corr_val)
        else
          :insufficient_data
        end

      _ ->
        :insufficient_data
    end
  end

  @doc """
  Processes correlation query results and interprets the trend.

  ## Parameters
  - result: Query result with correlation __data

  ## Returns
  - Trend interpretation (:improving, :degrading, :stable, :insufficient_data)

  ## Examples

      iex> result = %{rows: [[Decimal.new("0.5")]]}
      iex> Indrajaal.Shared.CorrelationAnalysis.process_correlation_result(result)
      :improving
  """
  @spec process_correlation_result(%{rows: list()}) ::
          :improving | :degrading | :stable | :insufficient_data
  @spec process_correlation_result(map()) :: term()
  def process_correlation_result(%{rows: [[correlation]] = _rows}) when not is_nil(correlation) do
    interpret_correlation(correlation)
  end

  @spec process_correlation_result(term()) :: term()
  def process_correlation_result(_result) do
    :insufficient_data
  end

  @doc """
  Calculates trend correlation for time - series __data using PostgreSQL CORR function.

  This function provides a standardized way to analyze trends in time - series __data
  by calculating the correlation between time (as epoch) and the metric values.

  ## Parameters
  - repo: Ecto repository module
  - query: SQL query string that should return correlation coefficient
  - __params: Query parameters list

  ## Returns
  - Trend interpretation (:improving, :degrading, :stable, :insufficient_data)
  """
  @spec calculate_trend_correlation(module(), String.t(), list()) ::
          :improving | :degrading | :stable | :insufficient_data
  @spec calculate_trend_correlation(term(), term(), term()) :: term()
  def calculate_trend_correlation(repo, query, params) do
    result = repo.query!(query, params)
    process_correlation_result(result)
  end
end
