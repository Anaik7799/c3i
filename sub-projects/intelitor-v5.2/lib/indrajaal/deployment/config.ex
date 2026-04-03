defmodule Indrajaal.Deployment.Config do
  alias Indrajaal.Support.CLILogger

  @moduledoc """
  Single Source of Truth (SSoT) for the Autonomic Container Ecosystem (ACE).
  """

  @spec containers(atom()) :: list(map())
  def containers(env_profile \\ :demo) do
    # ... (rest of the container definitions remain the same)
    [
      # 1. Database Layer (Infrastructure)
      %{
        service_name: "indrajaal-db",
        image_name: "indrajaal-timescaledb-demo",
        image_tag: "nixos-devenv",
        nix_file: "containers/indrajaal-timescaledb-demo.nix",
        # 5433 primary, 5432 internal replication
        ports: ["5433:5433", "5432:5432"],
        env: [
          "POSTGRES_USER=intelitor",
          "POSTGRES_PASSWORD=indrajaal_dev",
          "POSTGRES_DB=indrajaal_dev",
          "TS_TUNE_MEMORY=8GB",
          "TS_TUNE_NUM_CPUS=4"
        ],
        volumes: ["indrajaal-db-data:/var/lib/postgresql/data"],
        dependency_order: 1,
        health_check:
          {:cmd, ["pg_isready", "-U", "intelitor", "-p", "5433"], [interval: 2, retries: 60]}
      },

      # 2. Application Layer (Core Logic)
      %{
        service_name: "indrajaal-app",
        # ACE-Hardened Image
        image_name: "indrajaal-sopv51-elixir-app",
        image_tag: "nixos-devenv",
        nix_file: "containers/sopv51-elixir-app.nix",
        ports: app_ports(env_profile),
        env: app_env(env_profile),
        volumes: app_volumes(env_profile),
        # Starts after DB and Obs
        dependency_order: 3,
        health_check: {:http, "http://localhost:4000/health", [interval: 10, retries: 30]}
      },

      # 3. Observability Layer (Telemetry)
      %{
        service_name: "indrajaal-obs",
        # Placeholder for full stack
        image_name: "indrajaal-prometheus-demo",
        image_tag: "nixos-devenv",
        nix_file: "containers/indrajaal-prometheus-demo.nix",
        ports: ["9090:9090", "3000:3000", "4317:4317", "4318:4318"],
        env: [
          "GF_SECURITY_ADMIN_PASSWORD=admin",
          "OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317"
        ],
        volumes: ["indrajaal-obs-data:/var/lib/prometheus"],
        dependency_order: 2,
        health_check: {:http, "http://localhost:9090/-/healthy", [interval: 5, retries: 10]}
      }
    ]
  end

  defp app_ports(:prod), do: ["80:4000", "443:4001", "4369:4369"]
  defp app_ports(_), do: ["4000:4000", "4001:4001", "4369:4369"]

  defp app_env(env) do
    [
      "MIX_ENV=#{env}",
      "DATABASE_URL=ecto://intelitor:indrajaal_dev@indrajaal-db:5433/indrajaal_dev",
      "SECRET_KEY_BASE=hardened_secret_at_least_64_chars_long_for_bulletproof_setup_v2",
      "VTO_SHIELD_ENABLED=true",
      "PHICS_ENABLED=#{if env == :dev, do: "true", else: "false"}",
      "CONTAINER_MODE=#{env}",
      "ELIXIR_ERL_OPTIONS=+S 16:16 +SDio 16"
    ]
  end

  defp app_volumes(:dev) do
    [
      # PHICS Hot-Reloading
      "#{File.cwd!()}:/workspace:z",
      "app_deps:/workspace/deps",
      "app_build:/workspace/_build"
    ]
  end

  defp app_volumes(_), do: []

  def run_health_check_for(service_name, _opts \\ []) do
    config =
      containers()
      |> Enum.find(fn c -> c.service_name == service_name end)

    if config do
      execute_check(service_name, config.health_check)
    else
      {:error, "Service #{service_name} not found in ACE SSoT"}
    end
  end

  defp execute_check(service, {:cmd, command_args, opts}) do
    retries = Keyword.get(opts, :retries, 5)
    interval = Keyword.get(opts, :interval, 2)

    CLILogger.log("    Running CMD check for #{service}: #{Enum.join(command_args, " ")}")

    podman_cmd_args = ["exec", service] ++ command_args

    retry_loop(
      service,
      fn ->
        System.cmd("podman", podman_cmd_args)
      end,
      retries,
      interval
    )
  end

  defp execute_check(service, {:http, url, opts}) do
    retries = Keyword.get(opts, :retries, 5)
    interval = Keyword.get(opts, :interval, 2)

    CLILogger.log("    Running HTTP check for #{service}: #{url}")

    retry_loop(
      service,
      fn ->
        System.cmd("curl", ["-sf", "--max-time", "2", url])
      end,
      retries,
      interval
    )
  end

  defp retry_loop(_service, _check_fn, 0, _interval) do
    {:error, :health_check_timeout}
  end

  defp retry_loop(service, check_fn, retries, interval) do
    case check_fn.() do
      {_, 0} ->
        :ok

      {output, exit_code} ->
        CLILogger.log(
          "    -> Health check attempt ##{retries} failed. Retrying in #{interval}s..."
        )

        CLILogger.log("    -> Exit: #{exit_code}, Output: #{output}")
        Process.sleep(interval * 1000)
        retry_loop(service, check_fn, retries - 1, interval)
    end
  end
end
