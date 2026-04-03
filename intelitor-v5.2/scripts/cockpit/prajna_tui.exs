#!/usr/bin/env elixir
# PRAJNA TUI LAUNCHER
# Start the Prajna cockpit in terminal mode

defmodule PrajnaTUI do
  @moduledoc """
  Prajna Terminal User Interface Launcher

  Provides a full-screen terminal dashboard for Indrajaal system monitoring.
  """

  # ANSI codes
  @reset "\e[0m"
  @bold "\e[1m"
  @dim "\e[2m"
  @green "\e[32m"
  @yellow "\e[33m"
  @red "\e[31m"
  @blue "\e[34m"
  @cyan "\e[36m"
  @magenta "\e[35m"
  @clear "\e[2J\e[H"
  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"

  def run(args \\ []) do
    IO.write(@hide_cursor)
    IO.write(@clear)

    print_header()

    mode = parse_mode(args)

    case mode do
      :web -> launch_web_cockpit()
      :status -> show_system_status()
      :agents -> show_agent_status()
      :metrics -> show_metrics()
      :help -> show_help()
      _ -> interactive_menu()
    end
  rescue
    _ ->
      IO.write(@show_cursor)
      IO.puts("\n#{@red}[ERROR]#{@reset} TUI interrupted")
  after
    IO.write(@show_cursor)
  end

  defp print_header do
    IO.puts("""
    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}#{@magenta}प्रज्ञा#{@reset}  #{@bold}PRAJNA COCKPIT#{@reset}                                                   #{@cyan}║
    ║#{@reset}                                                                              #{@cyan}║
    ║#{@reset} #{@dim}Bio-Inspired • Safety-Critical • AI-Assisted#{@reset}                              #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    """)
  end

  defp interactive_menu do
    IO.puts("""
    #{@cyan}║#{@reset} #{@bold}Main Menu#{@reset}                                                                  #{@cyan}║
    #{@cyan}╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}[1]#{@reset} Launch Web Cockpit      #{@dim}(http://localhost:4000/cockpit)#{@reset}            #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}[2]#{@reset} System Status           #{@dim}Show current system health#{@reset}                 #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}[3]#{@reset} Agent Status            #{@dim}Show 7 agents + workers#{@reset}                    #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}[4]#{@reset} Live Metrics            #{@dim}Real-time telemetry stream#{@reset}                 #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}[5]#{@reset} Container Status        #{@dim}Show mesh containers#{@reset}                       #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}[6]#{@reset} AI Copilot              #{@dim}Interactive AI assistant#{@reset}                   #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@yellow}[q]#{@reset} Quit                                                                  #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}

    """)

    IO.write("#{@cyan}Select option:#{@reset} ")
    choice = IO.gets("") |> String.trim()

    case choice do
      "1" -> launch_web_cockpit()
      "2" -> show_system_status()
      "3" -> show_agent_status()
      "4" -> show_metrics()
      "5" -> show_container_status()
      "6" -> start_ai_copilot()
      "q" -> IO.puts("\n#{@green}Goodbye!#{@reset}\n")
      _ ->
        IO.puts("#{@yellow}Invalid option#{@reset}")
        :timer.sleep(1000)
        IO.write(@clear)
        print_header()
        interactive_menu()
    end
  end

  defp launch_web_cockpit do
    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}WEB COCKPIT#{@reset}                                                                #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   Starting Phoenix server with Prajna cockpit...                            #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@bold}Access URLs:#{@reset}                                                            #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} Main Cockpit     : #{@blue}http://localhost:4000/cockpit#{@reset}                    #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} Dashboard        : #{@blue}http://localhost:4000/cockpit/dashboard#{@reset}          #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} Startup Console  : #{@blue}http://localhost:4000/cockpit/startup#{@reset}            #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} Containers       : #{@blue}http://localhost:4000/cockpit/containers#{@reset}         #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} Mesh Status      : #{@blue}http://localhost:4000/cockpit/mesh#{@reset}               #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} AI Copilot       : #{@blue}http://localhost:4000/cockpit/ai-copilot#{@reset}         #{@cyan}║
    #{@cyan}║#{@reset}   #{@green}●#{@reset} Observability    : #{@blue}http://localhost:4000/cockpit/observability#{@reset}      #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@dim}Press Ctrl+C to stop the server#{@reset}                                         #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}

    """)

    IO.puts("#{@yellow}Starting Phoenix server...#{@reset}\n")
    System.cmd("mix", ["phx.server"], into: IO.stream(:stdio, :line))
  end

  defp show_system_status do
    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}SYSTEM STATUS#{@reset}                                                              #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    """)

    # Check containers
    {output, _} = System.cmd("podman", ["ps", "--format", "{{.Names}} {{.Status}}"], stderr_to_stdout: true)

    containers = output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "indrajaal"))

    if Enum.empty?(containers) do
      # Check for indrajaal containers (legacy)
      {output2, _} = System.cmd("podman", ["ps", "--format", "{{.Names}} {{.Status}}"], stderr_to_stdout: true)
      containers = output2
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "indrajaal"))
    end

    IO.puts("#{@cyan}║#{@reset} #{@bold}Containers:#{@reset}                                                                #{@cyan}║")

    Enum.each(containers, fn line ->
      if String.contains?(line, "Up") do
        IO.puts("#{@cyan}║#{@reset}   #{@green}●#{@reset} #{String.pad_trailing(line, 68)}#{@cyan}║")
      else
        IO.puts("#{@cyan}║#{@reset}   #{@red}○#{@reset} #{String.pad_trailing(line, 68)}#{@cyan}║")
      end
    end)

    IO.puts("""
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}
    """)

    IO.write("\n#{@dim}Press Enter to continue...#{@reset}")
    IO.gets("")
    IO.write(@clear)
    print_header()
    interactive_menu()
  end

  defp show_agent_status do
    agents = [
      {"OODA Controller", :standby, "Observe-Orient-Decide-Act Loop"},
      {"ACE Agent", :standby, "Autonomic Compute Engine"},
      {"Cortex Agent", :standby, "Cognitive Control System"},
      {"Fractal Logger", :standby, "5-Level Fractal Logging"},
      {"CEPAF Bridge", :standby, "Container/F# Integration"},
      {"Sentinel Guardian", :standby, "Health & Quorum Management"},
      {"KPI Dashboard", :standby, "Real-Time Progress Tracking"}
    ]

    workers = [
      {"FLAME Worker", :standby, "Elastic Compute Scaling"},
      {"Oban Worker", :standby, "Background Job Processing"},
      {"Broadway Worker", :standby, "Data Pipeline Processing"},
      {"Batch Worker", :standby, "Batch Operation Handling"}
    ]

    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}AGENT MESH STATUS (7 Agents)#{@reset}                                               #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    """)

    Enum.each(agents, fn {name, status, desc} ->
      icon = if status == :running, do: "#{@green}●", else: "#{@yellow}◆"
      IO.puts("#{@cyan}║#{@reset}   #{icon}#{@reset} #{String.pad_trailing(name, 20)} #{@dim}#{desc}#{@reset}")
    end)

    IO.puts("""
    #{@cyan}╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    #{@cyan}║#{@reset} #{@bold}WORKER MESH STATUS (4 Workers)#{@reset}                                             #{@cyan}║
    #{@cyan}╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    """)

    Enum.each(workers, fn {name, status, desc} ->
      icon = if status == :running, do: "#{@green}●", else: "#{@blue}◇"
      IO.puts("#{@cyan}║#{@reset}   #{icon}#{@reset} #{String.pad_trailing(name, 20)} #{@dim}#{desc}#{@reset}")
    end)

    IO.puts("""
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}
    """)

    IO.write("\n#{@dim}Press Enter to continue...#{@reset}")
    IO.gets("")
    IO.write(@clear)
    print_header()
    interactive_menu()
  end

  defp show_metrics do
    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}LIVE METRICS#{@reset}                                                                #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@dim}Streaming metrics... (Press Ctrl+C to stop)#{@reset}                             #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}

    """)

    # Start a simple metrics loop
    Stream.interval(1000)
    |> Enum.take(10)
    |> Enum.each(fn i ->
      mem = :erlang.memory(:total) |> div(1024 * 1024)
      procs = :erlang.system_info(:process_count)
      IO.puts("#{@cyan}[#{DateTime.utc_now() |> DateTime.to_iso8601()}]#{@reset} Memory: #{mem}MB | Processes: #{procs}")
    end)

    IO.write("\n#{@dim}Press Enter to continue...#{@reset}")
    IO.gets("")
    IO.write(@clear)
    print_header()
    interactive_menu()
  end

  defp show_container_status do
    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}CONTAINER STATUS#{@reset}                                                            #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    """)

    {output, _} = System.cmd("podman", ["ps", "-a", "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"], stderr_to_stdout: true)

    output
    |> String.split("\n")
    |> Enum.each(fn line ->
      if String.length(line) > 0 do
        IO.puts("#{@cyan}║#{@reset}   #{line}")
      end
    end)

    IO.puts("""
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}
    """)

    IO.write("\n#{@dim}Press Enter to continue...#{@reset}")
    IO.gets("")
    IO.write(@clear)
    print_header()
    interactive_menu()
  end

  defp start_ai_copilot do
    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}AI COPILOT#{@reset}                                                                  #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@dim}AI Copilot requires the Phoenix server to be running.#{@reset}                   #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   Access via: #{@blue}http://localhost:4000/cockpit/ai-copilot#{@reset}                   #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}
    """)

    IO.write("\n#{@dim}Press Enter to continue...#{@reset}")
    IO.gets("")
    IO.write(@clear)
    print_header()
    interactive_menu()
  end

  defp show_help do
    IO.puts("""

    #{@cyan}╔══════════════════════════════════════════════════════════════════════════════╗
    ║#{@reset} #{@bold}PRAJNA TUI HELP#{@reset}                                                             #{@cyan}║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{@reset}
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@bold}Usage:#{@reset} elixir scripts/cockpit/prajna_tui.exs [option]                    #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}║#{@reset}   #{@bold}Options:#{@reset}                                                                 #{@cyan}║
    #{@cyan}║#{@reset}     --web       Launch web cockpit (Phoenix server)                         #{@cyan}║
    #{@cyan}║#{@reset}     --status    Show system status                                          #{@cyan}║
    #{@cyan}║#{@reset}     --agents    Show agent/worker status                                    #{@cyan}║
    #{@cyan}║#{@reset}     --metrics   Stream live metrics                                         #{@cyan}║
    #{@cyan}║#{@reset}     --help      Show this help message                                      #{@cyan}║
    #{@cyan}║#{@reset}                                                                              #{@cyan}║
    #{@cyan}╚══════════════════════════════════════════════════════════════════════════════╝#{@reset}
    """)
  end

  defp parse_mode(args) do
    cond do
      "--web" in args -> :web
      "--status" in args -> :status
      "--agents" in args -> :agents
      "--metrics" in args -> :metrics
      "--help" in args or "-h" in args -> :help
      true -> :interactive
    end
  end
end

PrajnaTUI.run(System.argv())
