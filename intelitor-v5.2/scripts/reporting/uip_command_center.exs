defmodule Indrajaal.UIP.CommandCenter do
  @moduledoc """
  Unified Command Center for UIP Diagnostic Probes.
  Enforces parallel execution and high-fidelity reporting.
  """

  def run_full_audit() do
    IO.puts("\u001b[35m[UCC] INITIATING GLOBAL CONCURRENT AUDIT...\u001b[0m")
    
    tasks = [
      Task.async(fn -> run_probe("Substrate", "elixir scripts/agents/env_sentinel.exs --audit") end),
      Task.async(fn -> run_probe("Security", "elixir scripts/agents/security_sentry.exs --audit") end),
      Task.async(fn -> run_probe("F# Semantics", "dotnet fsi scripts/agents/fsharp_oracle.fsx lib/cepaf/src/Cepaf/Orchestrator/OptimalMesh.fs") end),
      Task.async(fn -> run_probe("Genotype", "node scripts/agents/yaml_oracle.js lib/cepaf/artifacts/podman-compose-fractal-cluster.yml") end)
    ]

    results = Task.await_many(tasks, 60_000)
    display_report(results)
  end

  defp run_probe(name, cmd) do
    IO.puts("[UCC] Probing #{name}...")
    {out, code} = System.cmd("bash", ["-c", cmd], stderr_to_stdout: true)
    %{name: name, output: out, status: if(code == 0, do: :pass, else: :fail)}
  end

  defp display_report(results) do
    IO.puts("\n\u001b[35m╔═══════════════════════════════════════════════════════════════════╗")
    IO.puts("║              UIP GLOBAL HEALTH PULSE (v2.0)                       ║")
    IO.puts("╠═══════════════════════════════════════════════════════════════════╣\u001b[0m")
    
    Enum.each(results, fn r ->
      status_color = if r.status == :pass, do: "\u001b[32m", else: "\u001b[31m"
      name = String.pad_trailing(r.name, 15)
      status = String.pad_trailing(Atom.to_string(r.status) |> String.upcase(), 10)
      summary = String.slice(r.output, 0, 35) |> String.replace("\n", " ") |> String.trim()
      
      IO.puts("║  #{name} : #{status_color}#{status}\u001b[0m | #{summary} ║")
    end)
    
    IO.puts("\u001b[35m╚═══════════════════════════════════════════════════════════════════╝\u001b[0m")
  end
end

Indrajaal.UIP.CommandCenter.run_full_audit()