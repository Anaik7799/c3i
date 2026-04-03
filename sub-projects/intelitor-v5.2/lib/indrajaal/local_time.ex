defmodule Indrajaal.LocalTime do
  @moduledoc """
  Centralized module for local time handling across the Indrajaal system.

  This module ensures all timestamps use current local time (CEST/CET) instead of UTC,
  as _required by CLAUDE.md mandatory rules.

  ## Usage

      # Get current local time
      Indrajaal.LocalTime.now()

      # Get formatted timestamp string
      Indrajaal.LocalTime.timestamp_string()
      #=> "2025-09-07 08:46:00 CEST"

      # Get timestamp for filenames
      Indrajaal.LocalTime.for_filename()
      #=> "20_250_907-0846"
  """

  @timezone "Europe/Berlin"

  @doc """
  Returns the current time in local timezone (Europe/Berlin).
  """
  def now do
    case DateTime.now(@timezone) do
      {:ok, datetime} ->
        datetime

      {:error, _} ->
        # Fallback to system time with manual timezone
        utc_time = DateTime.now!("Etc/UTC")
        DateTime.shift_zone!(utc_time, @timezone)
    end
  end

  @doc """
  Returns current local time as a formatted string.
  Format: "YYYY-MM-DD HH:MM:SS CEST/CET"
  """
  def timestamp_string do
    now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S %Z")
  end

  @doc """
  Returns timestamp formatted for use in filenames.
  Format: "YYYYMMDD-HHMM"
  """
  def for_filename do
    now()
    |> Calendar.strftime("%Y%m%d-%H%M")
  end

  @doc """
  Returns timestamp formatted for use in git commits and logs.
  Format: "2025-09-07T08:46:00+02:00"
  """
  def iso8601_local do
    now()
    |> DateTime.to_iso8601()
  end

  @doc """
  Returns just the date portion in local timezone.
  Format: "2025-09-07"
  """
  def date_string do
    now()
    |> DateTime.to_date()
    |> Date.to_string()
  end

  @doc """
  Returns just the time portion in local timezone.
  Format: "08:46:00"
  """
  def time_string do
    now()
    |> DateTime.to_time()
    |> Time.to_string()
  end

  @doc """
  Converts a UTC datetime to local timezone.
  """
  def from_utc(%DateTime{} = utc_datetime) do
    DateTime.shift_zone!(utc_datetime, @timezone)
  end

  @doc """
  Returns the current timezone abbreviation (CEST or CET).
  """
  def timezone_abbr do
    now()
    |> Calendar.strftime("%Z")
  end
end
