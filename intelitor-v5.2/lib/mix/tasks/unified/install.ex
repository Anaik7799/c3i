defmodule Mix.Tasks.Unified.Install do
  use Mix.Task

  @shortdoc "Run the unified installer for Indrajaal"

  @moduledoc """
  Executes the unified - 4.exs installer script with Mix integration.

  ## Usage

      mix unified.install [options]

  ## Options

    * `--profile <name>` - Installation profile (full, dev, minimal)
    * `--interactive` - Run in interactive mode (default)
    * `--config <file>` - Use configuration file

  ## Examples

      mix unified.install
      mix unified.install --profile dev
      mix unified.install --config config / unified.exs
  """

  @spec run(any()) :: any()
  def run(args) do
    IO.puts("[LAUNCH] Starting Unified Installer...")

    script_path = Path.join(["scripts", "installation", "unified - 4.exs"])

    if File.exists?(script_path) do
      # Pass arguments to unified installer
      System.cmd("elixir", [script_path | args], into: IO.stream(:stdio, :line))
    else
      IO.puts("❌ Error: unified - 4.exs not found at #{script_path}")
      IO.puts("Please ensure the script exists in scripts / installation/")
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
