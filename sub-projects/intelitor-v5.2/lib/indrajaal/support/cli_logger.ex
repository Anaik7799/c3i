defmodule Indrajaal.Support.CLILogger do
  @moduledoc """
  A simple CLI logger for scripts, providing clear, color-coded output.
  """

  def log(message) do
    IO.puts("✨ #{message}")
  end

  def log_cmd(message, _cmd_args, {"", 0}) do
    IO.puts("✅ CMD: #{message} -> Success (No Output)")
  end

  def log_cmd(message, _cmd_args, {output, 0}) do
    IO.puts("✅ CMD: #{message} -> Success")

    if output != :stdout do
      IO.puts("   Output: #{output}")
    end
  end

  def log_cmd(message, _cmd_args, {output, exit_code}) do
    IO.puts("❌ CMD: #{message} -> Failed (Exit Code: #{exit_code})")
    IO.puts("   Output: #{output}")
  end

  # This function was missing and caused an UndefinedFunctionError
  def start_session(_args) do
    # For now, just a placeholder. More sophisticated session management
    # could be added here if needed (e.g., logging to a file, timestamping).
    :ok
  end
end
