defmodule Indrajaal.Shared.TimeUtilities do
  @moduledoc """
  Shared utility functions for time - based operations and validations.

  This module provides reusable time utilities to eliminate code duplication
  across notifications and other time - sensitive modules.
  """

  @doc """
  Checks if a given time falls within a specified time range.

  Handles both normal ranges (e.g., 09:00 to 17:00) and overnight ranges
  (e.g., 22:00 to 07:00) where the end time is before the start time.

  ## Parameters
  - current: Current time to check
  - start_time: Start of the time range
  - end_time: End of the time range

  ## Returns
  - true if current time is within the range
  - false if current time is outside the range

  ## Examples

      # Normal range (9 AM to 5 PM)
      iex> Indrajaal.Shared.TimeUtilities.time_in_range?(~T[14:00:00], ~T[09:00:00], ~T[17:00:00])
      true

      iex> Indrajaal.Shared.TimeUtilities.time_in_range?(~T[08:00:00], ~T[09:00:00], ~T[17:00:00])
      false

      # Overnight range (10 PM to 7 AM)
      iex> Indrajaal.Shared.TimeUtilities.time_in_range?(~T[23:00:00], ~T[22:00:00], ~T[07:00:00])
      true

      iex> Indrajaal.Shared.TimeUtilities.time_in_range?(~T[06:00:00], ~T[22:00:00], ~T[07:00:00])
      true

      iex> Indrajaal.Shared.TimeUtilities.time_in_range?(~T[12:00:00], ~T[22:00:00], ~T[07:00:00])
      false
  """
  @spec time_in_range?(Time.t(), Time.t(), Time.t()) :: boolean()
  def time_in_range?(current, start_time, end_time) do
    if Time.compare(start_time, end_time) != :gt do
      # Normal range (start_time <= end_time)
      Time.compare(current, start_time) != :lt && Time.compare(current, end_time) != :gt
    else
      # Overnight range (start_time > end_time)
      Time.compare(current, start_time) != :lt || Time.compare(current, end_time) != :gt
    end
  end

  @doc """
  Checks if the current time is within business hours for a given timezone.

  ## Parameters
  - timezone: String timezone identifier (e.g., "America / New_York")
  - business_start: Start of business hours (default: 9:00 AM)
  - business_end: End of business hours (default: 5:00 PM)

  ## Returns
  - true if current time in timezone is within business hours
  - false otherwise
  """
  @spec in_business_hours?(String.t(), Time.t(), Time.t()) :: boolean()
  def in_business_hours?(timezone, business_start \\ ~T[09:00:00], business_end \\ ~T[17:00:00]) do
    case DateTime.now(timezone) do
      {:ok, current_datetime} ->
        current_time = DateTime.to_time(current_datetime)
        time_in_range?(current_time, business_start, business_end)

      {:error, _reason} ->
        false
    end
  end

  @doc """
  Validates that a time range is properly formatted.

  ## Parameters
  - start_time: Start time
  - end_time: End time

  ## Returns
  - {:ok, :normal} for normal ranges
  - {:ok, :overnight} for overnight ranges
  - {:error, reason} for invalid ranges
  """
  @spec validate_time_range(Time.t(), Time.t()) ::
          {:ok, :normal | :overnight} | {:error, String.t()}
  @spec validate_time_range(term(), term()) :: term()
  def validate_time_range(start_time, end_time) do
    cond do
      Time.compare(start_time, end_time) == :eq ->
        {:error, "Start time and end time cannot be equal"}

      Time.compare(start_time, end_time) == :lt ->
        {:ok, :normal}

      Time.compare(start_time, end_time) == :gt ->
        {:ok, :overnight}
    end
  end
end
