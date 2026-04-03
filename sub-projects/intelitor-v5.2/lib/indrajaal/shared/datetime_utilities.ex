defmodule Indrajaal.Shared.DatetimeUtilities do
  @moduledoc """
  Shared datetime utility functions for testing and __data generation.

  This module provides reusable datetime functions to eliminate duplicate
  code between test factories and performance helpers.
  """

  @doc """
  Generates a random datetime within the last 30 days.

  Useful for creating realistic test __data with recent timestamps.

  ## Examples

      iex> datetime = random_recent_datetime()
      iex> DateTime.diff(DateTime.utc_now(), datetime, :day)
      15  # Some number between 0 and 30
  """
  def random_recent_datetime do
    days_back = :rand.uniform(30)

    DateTime.utc_now()
    |> DateTime.add(-days_back * 24 * 60 * 60, :second)
    |> DateTime.add(-:rand.uniform(24 * 60 * 60), :second)
  end

  @doc """
  Generates a random datetime within a specific date range.

  Converts a Date.Range to a random DateTime within that range.

  ## Examples

      iex> range = Date.range(~D[2025 - 01 - 01], ~D[2025 - 01 - 31])
      iex> datetime = random_datetime_in_range(range)
      iex> datetime.year
      2025
  """
  @spec random_datetime_in_range(Date.Range.t()) :: DateTime.t()
  def random_datetime_in_range(%Date.Range{} = range) do
    dates = Enum.to_list(range)
    random_date = Enum.random(dates)

    random_time = %Time{
      hour: :rand.uniform(24) - 1,
      minute: :rand.uniform(60) - 1,
      second: :rand.uniform(60) - 1,
      microsecond: {0, 0}
    }

    DateTime.new!(random_date, random_time, "Etc / UTC")
  end

  @doc """
  Maybe returns a recent datetime with 70% probability, nil otherwise.

  Useful for optional timestamp fields in test data.
  """
  def maybe_recent_datetime do
    if :rand.uniform(100) <= 70 do
      random_recent_datetime()
    else
      nil
    end
  end

  @doc """
  Generates a datetime within a specific number of days in the past.

  ## Examples

      iex> datetime = datetime_days_ago(7)
      iex> days_diff = DateTime.diff(DateTime.utc_now(), datetime, :day)
      iex> days_diff >= 0 and days_diff <= 7
      true
  """
  @spec datetime_days_ago(non_neg_integer()) :: DateTime.t()
  def datetime_days_ago(max_days) when max_days >= 0 do
    days_back = :rand.uniform(max_days + 1) - 1

    DateTime.utc_now()
    |> DateTime.add(-days_back * 24 * 60 * 60, :second)
    |> DateTime.add(-:rand.uniform(24 * 60 * 60), :second)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
