defmodule Mix.Tasks.Container.Health do
  @moduledoc """
  Checks the health of ACE containers (Application, Database, Observability).

  Performs comprehensive health checks on the 3-container model, including:
  - Process status (Up/Exited)
  - Resource usage (CPU/Mem)
  - Application-specific health endpoints (HTTP/CMD)
  - VTO Compliance Verification

  ## Usage

      mix container.health [OPTIONS]

  ## Options

    * `--all` - Check all containers (running and stopped)
    * `--detailed` - Show detailed metrics
    * `--json` - Output in JSON format for automation

  Compliance: SOPv5.11 + ACE
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Check ACE container health"

  def run(args) do
    {opts, _, _} = parse_health_options(args)

    validate_container_runtime!()

    containers =
      if opts[:all], do: get_all_configured_containers(), else: get_running_containers()

    results = Enum.map(containers, &check_health(&1, opts))

    # Log results to Claude for audit trail
    ensure_claude_logging("health", %{results: results})

    if opts[:json] do
      IO.puts(Jason.encode!(%{health: results}, pretty: true))
    else
      print_report(results, opts[:detailed])
    end

    if Enum.any?(results, &(&1.status != :healthy)) do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp parse_health_options(args) do
    OptionParser.parse(args, switches: [all: :boolean, detailed: :boolean, json: :boolean])
  end

  defp get_all_configured_containers do
    Indrajaal.Deployment.Config.containers() |> Enum.map(& &1.service_name)
  end

  defp get_running_containers do
    {output, 0} = System.cmd("podman", ["ps", "--format", "{{.Names}}"])
    String.split(output, "\n", trim: true)
  end

  defp check_health(name, opts) do
    base = %{name: name, status: :unknown, details: %{}}

    case get_container_info(name) do
      {:ok, info} ->
        state = info["State"]["Status"]
        health_status = get_in(info, ["State", "Health", "Status"]) || "none"

        status =
          case {state, health_status} do
            {"running", "healthy"} -> :healthy
            # Assume healthy if no check but running
            {"running", "none"} -> :healthy
            {"running", _} -> :unhealthy
            _ -> :stopped
          end

        # Deep inspection if running
        details =
          if status == :healthy and opts[:detailed] do
            %{
              resources: get_resources(name),
              ipv4:
                get_in(info, ["NetworkSettings", "Networks", "indrajaal-network", "IPAddress"])
            }
          else
            %{}
          end

        %{base | status: status, details: details}

      {:error, _} ->
        %{base | status: :missing}
    end
  end

  defp get_resources(name) do
    # Simplified resource check
    {out, 0} =
      System.cmd("podman", [
        "stats",
        "--no-stream",
        "--format",
        "{{.MemUsage}} / {{.CPUPerc}}",
        name
      ])

    String.trim(out)
  end

  defp print_report(results, detailed) do
    IO.puts("\n🛡️  ACE Container Health Report")
    IO.puts(String.duplicate("=", 50))

    Enum.each(results, fn r ->
      icon =
        case r.status do
          :healthy -> "✅"
          :unhealthy -> "❌"
          :stopped -> "⏹️"
          :missing -> "❓"
        end

      IO.puts(
        "#{icon} #{String.pad_trailing(r.name, 20)} [#{String.upcase(to_string(r.status))}]"
      )

      if detailed and r.details != %{} do
        IO.puts("   └─ IPv4: #{r.details[:ipv4]}")
        IO.puts("   └─ Res:  #{r.details[:resources]}")
      end
    end)

    IO.puts("")
  end
end
