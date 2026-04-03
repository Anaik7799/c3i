# scripts/reporting/smart_system_state.exs
# Biomorphic OODA Observation Script
# Compliant with GEMINI.md Section 77.2

Mix.install([{:jason, "~> 1.4"}])

# Load biomorphic dependencies
Code.require_file("lib/indrajaal/network/registry.ex")

defmodule SmartSystemState do
  @zenoh_url "http://localhost:8000"

  def run do
    # Load biomorphic registry
    {:ok, nodes} = Indrajaal.Network.Registry.list_nodes()

    state = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      phase: detect_phase(),
      quality_gates: %{
        compilation: check_compilation(),
        tests: "pending",
        format: check_format(),
        homeostasis: get_biomorphic_health(),
        # SC-REGEN-002: Holographic Parity Check
        holographic_parity: check_holographic_parity()
      },
      context: %{
        git_branch: get_git_branch(),
        swarm_status: get_swarm_status(),
        ooda_cycle: get_ooda_metrics(),
        # SC-NET-001: FQDN Awareness
        nodes: Enum.map(nodes, fn {_key, node} -> %{id: node["id"], fqdn: node["fqdn"]} end)
      }
    }
    
    IO.puts(Jason.encode!(state, pretty: true))
  end

  defp get_biomorphic_health do
    case System.cmd("curl", ["-sf", "#{@zenoh_url}/indrajaal/health/indrajaal-ex-app-1"]) do
      {_, 0} -> "healthy"
      _ -> "unhealthy"
    end
  end

  defp get_swarm_status do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"]) do
      {output, 0} ->
        count = output |> String.split("\n", trim: true) |> length()
        "#{count}/15 nodes active"
      _ -> "error"
    end
  end

  defp get_ooda_metrics do
    case System.cmd("curl", ["-sf", "#{@zenoh_url}/indrajaal/metrics/ooda"]) do
      {output, 0} -> 
        try do
          Jason.decode!(output)
        rescue
          _ -> "active"
        end
      _ -> "igniting"
    end
  end

  defp get_git_branch do
    try do
      {branch, 0} = System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"])
      String.trim(branch)
    rescue
      _ -> "unknown"
    end
  end

  defp check_compilation do
    # Try Zenoh remote health first
    case System.cmd("curl", ["-sf", "#{@zenoh_url}/indrajaal/health/compilation"]) do
      {_, 0} -> "pass"
      _ -> 
        # Fallback: Trigger local parallelized verification
        env = [
          {"NO_TIMEOUT", "true"},
          {"PATIENT_MODE", "enabled"},
          {"ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16"},
          {"MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8"}
        ]
        case System.cmd("mix", ["compile", "--warnings-as-errors", "--jobs", "16"], env: env, stderr_to_stdout: true) do
          {_, 0} -> "pass"
          _ -> "fail"
        end
    end
  end

  defp check_format do
    case System.cmd("mix", ["format", "--check-formatted"], stderr_to_stdout: true) do
      {_, 0} -> "pass"
      _ -> "fail"
    end
  end

  defp check_holographic_parity do
    # Check if the RegenerationSwarm is reporting a healthy parity status
    case System.cmd("curl", ["-sf", "#{@zenoh_url}/indrajaal/health/regeneration_swarm"]) do
      {_, 0} -> "aligned"
      _ -> "entropic"
    end
  end

  defp detect_phase do
    "development"
  end
end

SmartSystemState.run()
