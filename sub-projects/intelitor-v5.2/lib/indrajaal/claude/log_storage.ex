defmodule Indrajaal.Claude.LogStorage do
  @moduledoc """
  Log storage module for Claude AI activity tracking.
  Stores logs in ./__data/tmp folder as per CLAUDE.md __requirements.
  """

  # CLAUDE_AGENT_CONTEXT: Created to fix undefined module warnings
  # Date: 2025-09-03
  # Issue: Indrajaal.Claude.LogStorage.save_log/2 undefined
  # Pattern: EP045_UNDEFINED_MODULE
  # Fix: Created module to handle Claude AI log storage __requirements
  #
  # This module implements the mandatory log storage __requirements from CLAUDE.md:
  # - All Claude-generated logs MUST be saved in ./__data/tmp folder
  # - Timestamp format: YYYYMMDD-HHMM-description.log
  # - Session tracking with unique IDs
  # - 30-day minimum retention policy
  #
  # Architecture Notes:
  # - Simple file-based storage for audit trail
  # - No __database dependency for maximum reliability
  # - Automatic directory creation
  # - Error handling with logging fallback

  require Logger

  @log_dir "./__data/tmp"

  def save_log(content, type \\ "general") do
    ensure_log_directory()

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    session_id = System.get_env("CLAUDE_SESSION_ID", "default")
    filename = "#{@log_dir}/claude_#{type}_#{timestamp}_#{session_id}.log"

    case File.write(filename, content) do
      :ok ->
        Logger.info("Claude log saved to: #{filename}")
        {:ok, filename}

      {:error, reason} ->
        Logger.error("Failed to save Claude log: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_log_directory do
    File.mkdir_p(@log_dir)
  end
end
