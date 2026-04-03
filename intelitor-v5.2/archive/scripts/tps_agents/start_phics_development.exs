# 1.0 - Hierarchical Numbering Integration
# 1.0 - This script supports hierarchical task numbering as defined in CLAUDE.m

defmodule HierarchicalNumbering do
  @spec format_task_id(term(), term(), term(), term(), term()) :: any()
  def format_task_id(category, task, subtask \\ nil, step \\ nil, microtask \\ nil) do
    base = "#{category}.#{task}"
    base = if subtask, do: base <> ".#{subtask}", else: base
    base = if step, do: base <> ".#{step}", else: base
    if microtask, do: base <> ".#{microtask}", else: base
  end

  @spec validate_task_id(any()) :: any()
  def validate_task_id(id) do
    Regex.match?(~r/^[1-9].[0-9]+(.[0-9]+)*$/, id)
  end
end

#!/usr/bin/env elixir

# 1.0 - Load __required modules
Code.__require_file("lib/intelitor/container_compliance.ex")

defmodule StartPhicsDevelopment do
  @moduledoc """
  SOP v5.1 Cybernetic Goal-Oriented Execution Framework
  Converted from shell script: scripts/tps_agents/start_phics_development.sh
  MANDATORY: PHICS container and Claude-based approach compliance
  """

  @spec main(any()) :: any()
  def main(args \\ []) do
    IO.puts("🔄 Running start_phics_development (converted from shell)")

    # 1.0 - TODO: Convert shell commands to Elixir System.cmd calls
    # 1.0 - Original shell content was:
    # #!/bin/bash
    # 1.1 - echo "🚀 Starting PHICS development workflow..."
    #
    # # Start development container with hot-reload
    # 1.1 - podman run -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -d --name intelitor-phics-
    #   -p 4000:4000 -p 4001:4001 \
    #   -v /home/an/dev/elixir/ash/intelitor:/workspace:z \
    # 1.1 - localhost:5001/intelitor-phics-dev:latest
    #
    # # Start file watcher in background
    # ./scripts/tps_agents/phics_container_watcher.sh &
    #
    # 1.1 - echo "✅ PHICS development environment running"
    # 1.1 - echo "🌐 Application: http://localhost:4000"
    # 1.1 - echo "🔥 Hot-reload: Active"
    #

    IO.puts("⚠️  MANUAL CONVERSION REQUIRED")
    IO.puts("Shell script backed up to: scripts/tps_agents/start_phics_development.sh.backup")
    IO.puts("Please implement the shell logic using Elixir System.cmd/3")

    System.halt(0)
  end
end

# 1.0 - Execute if run directly
StartPhicsDevelopment.main(System.argv())
