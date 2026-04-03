#!/usr/bin/env elixir

defmodule SMRITI.Dashboard do
  def run do
    IO.puts IO.ANSI.clear()
    IO.puts IO.ANSI.home()
    
    IO.puts [IO.ANSI.cyan(), "┌──────────────────────────────────────────────────────────────────┐", IO.ANSI.reset()]
    IO.puts [IO.ANSI.cyan(), "│  SMRITI CYBERNETIC EXECUTION DASHBOARD                             │", IO.ANSI.reset()]
    IO.puts [IO.ANSI.cyan(), "├──────────────────────────────────────────────────────────────────┤", IO.ANSI.reset()]

    case File.read(".smriti_progress.json") do
      {:ok, content} ->
        try do
          # Simple JSON parsing if Jason isn't available in script mode, 
          # but we should assume Jason is available or use simple regex/map for this standalone script if needed.
          # To be safe and dependency-free, we'll try to use Mix if available, or just regex parse specific keys for now
          # since we can't guarantee compiled deps in a standalone .exs easily without Mix.install
          
          # Actually, let's use Mix.install for safety if we are 1.12+
          display_json(content)
        rescue
          _ -> display_error("JSON Parse Error")
        end
      {:error, _} ->
        display_error("State File Not Found (.smriti_progress.json)")
    end
    
    IO.puts [IO.ANSI.cyan(), "└──────────────────────────────────────────────────────────────────┘", IO.ANSI.reset()]
    IO.puts "\nUpdated: #{DateTime.utc_now() |> DateTime.to_string()}"
  end

  defp display_json(content) do
    # Hacky simple parsing for the dashboard to avoid Mix.install latency in a loop loop if called repeatedly
    # But for this task, let's just grep the status keys.
    
    tracks = ~w(A_IMMORTALITY B_FEDERATION C_AUTOMATION D_POLISH)
    
    Enum.each(tracks, fn track ->
      status = extract_status(content, track)
      color = status_color(status)
      IO.puts [IO.ANSI.cyan(), "│  ", IO.ANSI.reset(), "#{pad(track, 15)}", " │ ", color, "#{pad(status, 15)}", IO.ANSI.reset(), "                  │"]
    end)
    
    IO.puts [IO.ANSI.cyan(), "├──────────────────────────────────────────────────────────────────┤", IO.ANSI.reset()]
    
    tests_passed = extract_metric(content, "total_tests_passed")
    IO.puts [IO.ANSI.cyan(), "│  ", IO.ANSI.reset(), "TESTS PASSED    ", " │ ", IO.ANSI.green(), "#{pad(tests_passed, 15)}", IO.ANSI.reset(), "                  │"]
  end

  defp extract_status(json, track) do
    case Regex.run(~r/"#{track}":\s*\{\s*\"status\":\s*\"([^\"]+)\"/, json) do
      [_, status] -> status
      _ -> "unknown"
    end
  end
  
  defp extract_metric(json, metric) do
    case Regex.run(~r/"#{metric}":\s*(\d+)/, json) do
      [_, val] -> val
      _ -> "0"
    end
  end

  defp status_color("completed"), do: IO.ANSI.green()
  defp status_color("in_progress"), do: IO.ANSI.yellow()
  defp status_color("pending"), do: IO.ANSI.red()
  defp status_color(_), do: IO.ANSI.white()

  defp pad(str, len) do
    String.pad_trailing(str, len)
  end

  defp display_error(msg) do
    IO.puts [IO.ANSI.cyan(), "│  ", IO.ANSI.red(), "ERROR: #{msg}", IO.ANSI.reset(), "                               │"]
  end
end

SMRITI.Dashboard.run()
