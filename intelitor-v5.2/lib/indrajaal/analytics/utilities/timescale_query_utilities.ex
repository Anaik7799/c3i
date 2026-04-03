defmodule TimescaleQueryUtilities do
  @moduledoc """
  Utility functions for building TimescaleDB queries.
  """

  @spec build_event_count_query(String.t(), DateTime.t(), DateTime.t()) :: String.t()
  def build_event_count_query(event_type, start_time, end_time) do
    """
    SELECT COUNT(*) as count
    FROM __events
    WHERE __event_type = '#{event_type}'
    AND time >= '#{start_time}'
    AND time <= '#{end_time}'
    """
  end

  @spec build_alarm_resolution_query(String.t(), DateTime.t(), DateTime.t(), String.t()) ::
          String.t()
  def build_alarm_resolution_query(alarm_id, start_time, end_time, resolution_type) do
    """
    SELECT *
    FROM alarm_resolutions
    WHERE alarm_id = '#{alarm_id}'
    AND resolution_type = '#{resolution_type}'
    AND time >= '#{start_time}'
    AND time <= '#{end_time}'
    """
  end
end
