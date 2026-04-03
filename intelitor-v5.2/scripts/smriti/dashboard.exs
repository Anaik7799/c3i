defmodule SMRITI.Dashboard do
  def run do
    IO.write(:stdio, "\e[H\e[2J") # Clear screen
    
    case File.read(".smriti_progress.json") do
      {:ok, content} ->
        state = Jason.decode!(content)
        render(state)
      _ -> 
        IO.puts("Initializing state...")
    end
    
    Process.sleep(30_000) # Update every 30s
    run()
  end

  def render(state) do
    IO.puts <<""
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  SMRITI FRACTAL COMPLETION DASHBOARD                                           ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  STATUS: #{String.pad_trailing(state["status"], 60)}║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  TRACK A: IMMORTALITY  [#{bar(state["tracks"]["A"])}] #{state["tracks"]["A"]}%
    ║  TRACK B: FEDERATION   [#{bar(state["tracks"]["B"])}] #{state["tracks"]["B"]}%
    ║  TRACK C: AUTOMATION   [#{bar(state["tracks"]["C"])}] #{state["tracks"]["C"]}%
    ║  TRACK D: POLISH       [#{bar(state["tracks"]["D"])}] #{state["tracks"]["D"]}%
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  ACTIVE TASKS:                                                               
    #{render_tasks(state["tasks"])    }
    ╚══════════════════════════════════════════════════════════════════════════════╝
    >>
  end

  defp bar(percent) do
    filled = div(percent, 5)
    empty = 20 - filled
    String.duplicate("█", filled) <> String.duplicate("░", empty)
  end

  defp render_tasks(tasks) do
    tasks
    |> Enum.map(fn {k, v} -> "║  " <> String.pad_trailing(k, 25) <> " : " <> v end)
    |> Enum.join("\n")
    |> String.pad_trailing(76)
  end
end

Mix.install([{:jason, "~> 1.4"}])
SMRITI.Dashboard.run()
