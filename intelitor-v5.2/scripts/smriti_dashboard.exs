Mix.install([{:jason, "~> 1.4"}])

defmodule SMRTIDashboard do
  def run do
    args = System.argv()
    if "--watch" in args do
      watch_loop()
    else
      render()
    end
  end

  def watch_loop do
    IO.write("\x1b[2J\x1b[H") # Clear screen
    render()
    Process.sleep(30_000)
    watch_loop()
  end

  def render do
    case File.read(".smriti_progress.json") do
      {:ok, content} ->
        state = Jason.decode!(content)
        print_dashboard(state)
      {:error, _} ->
        IO.puts("Waiting for SMRITI state...")
    end
  end

  defp print_dashboard(state) do
    IO.puts """
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║  SMRITI AUTONOMOUS EXECUTION DASHBOARD                                   ║
    ╠══════════════════════════════════════════════════════════════════════════╣
    ║  Status: #{String.upcase(state["status"])} | Phase: #{state["phase"]}
    ║  Started: #{state["start_time"]}
    ╟──────────────────────────────────────────────────────────────────────────╢
    """

    Enum.each(state["tracks"], fn {name, info} ->
      status_icon = case info["status"] do
        "completed" -> "✅"
        "running" -> "🔄"
        "verifying" -> "🔍"
        _ -> "⏳"
      end
      
      IO.puts "    #{status_icon} #{name}: #{String.upcase(info["status"])} (Verification: #{info["verification"] || "pending"})"
    end)

    metrics = state["metrics"]
    IO.puts """
    ╟──────────────────────────────────────────────────────────────────────────╢
    ║  METRICS
    ║  Tests Created: #{metrics["tests_created"] || metrics["total_tests_created"]}
    ║  Modules Impl : #{metrics["modules_implemented"] || metrics["total_modules"]}
    ║  Tests Passed : #{metrics["tests_passed"] || metrics["total_tests_passed"]}
    ╚══════════════════════════════════════════════════════════════════════════╝
    """
  end
end

SMRTIDashboard.run()
