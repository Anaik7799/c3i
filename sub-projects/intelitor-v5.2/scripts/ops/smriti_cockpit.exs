#!/usr/bin/env elixir
Mix.install([{:jason, "~> 1.4"}])

defmodule SMRITI.Cockpit do
  @moduledoc """
  TUI Cockpit for SMRITI.
  Implements the Ecosystem (L8) UI/UX capabilities.
  """

  def run do
    loop(%{
      node_id: "node_alpha",
      peers: ["node_beta", "node_gamma"],
      logs: ["System started."]
    })
  end

  defp loop(state) do
    render(state)
    command = IO.gets("> ") |> String.trim()
    
    new_state = case command do
      "r" -> add_log(state, "State refreshed.")
      "s" -> 
        perform_sync()
        add_log(state, "Federation Sync Triggered.")
      "e" -> 
        IO.puts("\n🛑 EMERGENCY STOP TRIGGERED 🛑")
        System.halt(1)
      "q" -> 
        IO.puts("Goodbye.")
        System.halt(0)
      _ -> state
    end

    loop(new_state)
  end

  defp render(state) do
    clear_screen()
    IO.puts """
    ╭──────────────────────────────────────────────────────────────────────────╮
    │  SMRITI BIOMORPHIC COCKPIT v1.0                                [ACTIVE]    │
    │  Node: #{String.pad_trailing(state.node_id, 20)} Clock: #{DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()} │
    ╰──────────────────────────────────────────────────────────────────────────╯
    
    [ L6: FEDERATION MESH ]
    ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
    │ #{state.node_id}   │ <--> │ #{Enum.at(state.peers, 0)}    │ <--> │ #{Enum.at(state.peers, 1)}   │
    │ (Local)      │      │ (Synced)     │      │ (Lag: 2ms)   │
    └──────────────┘      └──────────────┘      └──────────────┘

    [ L2: OODA AGENT LOG ]
    "
    
    state.logs 
    |> Enum.take(-5) 
    |> Enum.each(fn log -> IO.puts("    ➜ #{log}") end)

    IO.puts """
    
    [ CONTROLS ]
    [r] Refresh  [s] Sync Mesh  [e] Emergency Stop  [q] Quit
    ""
  end

  defp add_log(state, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.truncate(:second) |> Time.to_string()
    new_logs = state.logs ++ ["#{timestamp} - #{message}"]
    Map.put(state, :logs, new_logs)
  end

  defp perform_sync do
    # Simulate work
    Process.sleep(500)
  end

  defp clear_screen do
    IO.write("\x1b[2J\x1b[H")
  end
end

SMRITI.Cockpit.run()
