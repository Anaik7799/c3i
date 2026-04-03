#!/usr/bin/env elixir

Mix.install([
  {:kino, "~> 0.12.0"},
  {:jason, "~> 1.4"},
  {:table_rex, "~> 3.1.1"}
])

defmodule Prometheus.Dashboard do
  @moduledoc """
  Intelligent Information Rich Dashboard for Indrajaal v20.0.
  Implements SC-PROM-003 and AOR-PROM-001.
  """

  @refresh_interval 30_000 # 30 seconds
  @redline_threshold 95
  @target_utilization 200

  def run do
    clear_screen()
    print_header()
    
    # 1. Observe (Simulated for initial bootstrap, would connect to Zenoh/Telemetry)
    state = observe_system_state()
    
    # 2. Orient & Decide (Metabolism)
    scaling_decision = calculate_metabolic_scaling(state)
    
    # 3. Render Dashboard
    render_global_kpis(state)
    render_metabolism(state, scaling_decision)
    render_agent_swarm(state)
    render_tasks(state)
    
    # 4. Act (Simulated Scaling)
    apply_scaling(scaling_decision)
    
    # Loop
    Process.sleep(1000) # Keep script alive for a moment to display, real loop external
  end

  defp clear_screen, do: IO.write("\e[2J\e[H")

  defp print_header do
    IO.puts IO.ANSI.cyan() <> "╔══════════════════════════════════════════════════════════════════════════════╗"
    IO.puts "║ INDRAJAAL v20.0 :: PROMETHEUS COCKPIT :: BIOMORPHIC FRACTAL MODE             ║"
    IO.puts "╚══════════════════════════════════════════════════════════════════════════════╝" <> IO.ANSI.reset()
  end

  defp observe_system_state do
    # In a real run, this fetches from SystemRegistry/ETS/Zenoh
    %{ 
      timestamp: DateTime.utc_now(),
      agents: [
        %{id: "L5-SUP", status: :thinking, load: 45, task: "Orchestrating Phase 24.2"},
        %{id: "L4-FAME", status: :working, load: 88, task: "Schema Validation"},
        %{id: "L4-SEC", status: :idle, load: 5, task: "Waiting for Audit"},
        %{id: "L4-CEPAF", status: :working, load: 72, task: "Container Provisioning"}
      ],
      api_metrics: %{
        tpm: 145_000,
        rpm: 45,
        limit_usage: 78.5, # Percentage
        errors: 0
      },
      plan: %{
        completion: 87.5,
        eta: "2h 15m",
        active_phase: "24.2 Nervous System Repair"
      }
    }
  end

  defp calculate_metabolic_scaling(state) do
    usage = state.api_metrics.limit_usage
    cond do
      usage > @redline_threshold -> {:scale_down, "CRITICAL: Approaching API Redline"}
      usage < 50 -> {:scale_up, "Metabolism Low: Spawning Agents"}
      true -> {:maintain, "Homeostasis"}
    end
  end

  defp render_global_kpis(state) do
    IO.puts "\n" <> IO.ANSI.bright() <> "--- 🌍 GLOBAL FRACTAL STATE ---" <> IO.ANSI.reset()
    IO.puts "Phase: #{state.plan.active_phase}"
    IO.puts "Progress: [#{progress_bar(state.plan.completion)}] #{state.plan.completion}% | ETA: #{state.plan.eta}"
  end

  defp render_metabolism(state, {action, reason}) do
    IO.puts "\n" <> IO.ANSI.bright() <> "--- ⚡ METABOLISM & API HEALTH ---" <> IO.ANSI.reset()
    
    color = if state.api_metrics.limit_usage > 80, do: IO.ANSI.red(), else: IO.ANSI.green()
    
    IO.puts "API Load: #{color}#{state.api_metrics.limit_usage}%#{IO.ANSI.reset()} (Target: #{@target_utilization}% Virtual)"
    IO.puts "TPM: #{state.api_metrics.tpm} | RPM: #{state.api_metrics.rpm} | Errors: #{state.api_metrics.errors}"
    IO.puts "Decision: #{IO.ANSI.yellow()}#{inspect(action)}#{IO.ANSI.reset()} -> #{reason}"
  end

  defp render_agent_swarm(state) do
    IO.puts "\n" <> IO.ANSI.bright() <> "--- 🤖 AGENT SWARM THINKING ---" <> IO.ANSI.reset()
    
    state.agents
    |> Enum.each(fn agent ->
      status_icon = case agent.status do
        :thinking -> "🧠"
        :working -> "🔨"
        :idle -> "💤"
      end
      
      IO.puts "#{status_icon} #{IO.ANSI.white()}#{agent.id}#{IO.ANSI.reset()}: #{agent.task} (#{agent.load}% Load)"
    end)
  end

  defp render_tasks(_state) do
    # Placeholder for detailed task table
    :ok
  end

  defp apply_scaling({action, _reason}) do
    # In reality, this calls the Supervisor to start/stop children
    case action do
      :scale_up -> IO.puts(IO.ANSI.blue() <> ">> SPAWNING NEW AGENTS..." <> IO.ANSI.reset())
      :scale_down -> IO.puts(IO.ANSI.red() <> ">> HIBERNATING AGENTS..." <> IO.ANSI.reset())
      :maintain -> :ok
    end
  end

  defp progress_bar(percent) do
    width = 40
    filled = round(percent / 100 * width)
    empty = width - filled
    String.duplicate("█", filled) <> String.duplicate("░", empty)
  end
end

Prometheus.Dashboard.run()
