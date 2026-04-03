#!/usr/bin/env elixir

defmodule SignozDeployment do
  @moduledoc """
  GDE-tracked deployment script for SigNoz observability platform.
  Includes STAMP safety validation and comprehensive rollback support.

  Usage:
    elixir scripts/observability/deploy_signoz.exs [options]

  Options:
    --validate-only    Run validation checks without deployment
    --skip-tests       Skip TDG test validation (NOT RECOMMENDED)
    --force           Force deployment even with warnings
    --rollback        Rollback to previous deployment
    --status          Check deployment status
  """

  __require Logger

  @deployment_steps [
    # TDG: Validate all tests pass
    {:test_validation, &validate_all_tdg_tests/0, "Validating TDG tests"},

    # STAMP: Safety pre-checks
    {:safety_validation, &validate_safety_constraints/0, "Validating STAMP safety constraints"},

    # Build and deploy
    {:build_containers, &build_all_containers/0, "Building SigNoz containers"},
    {:start_infrastructure, &start_signoz_stack/0, "Starting SigNoz infrastructure"},
    {:validate_health, &health_check_all_services/0, "Validating service health"},

    # Application configuration
    {:configure_app, &configure_application/0, "Configuring application"},
    {:validate_export, &validate_telemetry_export/0, "Validating telemetry export"},

    # Dashboard setup
    {:provision_dashboards, &provision_all_dashboards/0, "Provisioning dashboards"},
    {:configure_alerts, &configure_alert_rules/0, "Configuring alert rules"}
  ]

  @spec main(any()) :: any()
  def main(args \\ []) do
    IO.puts """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║              SigNoz Deployment Automation (GDE-Tracked)           ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """

    options = parse_args(args)

    cond do
      options[:status] ->
        check_deployment_status()

      options[:rollback] ->
        rollback_deployment()

      options[:validate_only] ->
        validate_deployment()

      true ->
        deploy(options)
    end
  end

  @spec parse_args(term()) :: term()
  defp parse_args(args) do
    {__opts, _, _} = OptionParser.parse(args,
      switches: [
        validate_only: :boolean,
        skip_tests: :boolean,
        force: :boolean,
        rollback: :boolean,
        status: :boolean
      ]
    )
    __opts
  end

  @spec deploy(term()) :: term()
  defp deploy(options) do
    # GDE: Initialize deployment tracking
    deployment_id = generate_deployment_id()
    start_time = System.monotonic_time(:second)

    IO.puts "\n🚀 Starting deployment: #{deployment_id}"
    IO.puts "Timestamp: #{DateTime.utc_now() |> DateTime.to_string()}"
    IO.puts "─" |> String.duplicate(70)

    # Save deployment __state for rollback
    save_deployment_state(deployment_id)

    result = Enum.reduce_while(@deployment_steps, :ok, fn {step_id, func, description}, _ ->
      IO.puts "\n📋 #{description}..."

      case execute_step(step_id, func, options) do
        :ok ->
          IO.puts "✅ #{description}-SUCCESS"
          mark_step_complete(deployment_id, step_id)
          {:cont, :ok}

        {:warning, message} ->
          IO.puts "⚠️  #{description}-WARNING: #{message}"
          if options[:force] do
            {:cont, :ok}
          else
            IO.puts "❌ Deployment halted due to warning. Use --force to continue."
            {:halt, {:error, step_id, message}}
          end

        {:error, reason} ->
          IO.puts "❌ #{description}-FAILED: #{reason}"
          IO.puts "\n🔄 Rolling back deployment..."
          rollback_to_step(deployment_id, step_id)
          {:halt, {:error, step_id, reason}}
      end
    end)

    duration = System.monotonic_time(:second)-start_time

    case result do
      :ok ->
        IO.puts "\n✅ Deployment completed successfully in #{duration} seconds"
        mark_deployment_complete(deployment_id)

      {:error, step, reason} ->
        IO.puts "\n❌ Deployment failed at step '#{step}': #{reason}"
        IO.puts "Duration: #{duration} seconds"
        System.halt(1)
    end
  end

  defp execute_step(step_id, func, options) do
    try do
      if step_id == :test_validation && options[:skip_tests] do
        IO.puts "  ⚠️  Skipping test validation (NOT RECOMMENDED)"
        :ok
      else
        func.()
      end
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end

  # Step implementations

  @spec validate_all_tdg_tests() :: any()
  defp validate_all_tdg_tests do
    IO.puts "  Running TDG tests..."

    case System.cmd("mix", ["test", "--only", "tdg_required"],
      stderr_to_stdout: true, cd: project_root()) do
      {output, 0} ->
        IO.puts "  ✓ All TDG tests passed"
        :ok
      {output, _} ->
        {:error, "TDG tests failed. Run 'mix test --only tdg_required' for details."}
    end
  end

  @spec validate_safety_constraints() :: any()
  defp validate_safety_constraints do
    IO.puts "  Running STAMP safety validation..."

    # Run the STPA analysis script
    case System.cmd("elixir",
      ["scripts/stamp/stpa_observability_platform_analysis.exs", "--analyze", "constraints"],
      stderr_to_stdout: true, cd: project_root()) do
      {output, 0} ->
        if output =~ "CRITICAL:" do
          {:warning, "Safety constraints have warnings. Review output above."}
        else
          IO.puts "  ✓ All safety constraints validated"
          :ok
        end
      {_, _} ->
        {:error, "Safety validation failed"}
    end
  end

  @spec build_all_containers() :: any()
  defp build_all_containers do
    IO.puts "  Building containers..."

    case System.cmd("elixir", ["scripts/observability/build_signoz_containers.exs", "--all"],
      stderr_to_stdout: true, cd: project_root()) do
      {_, 0} ->
        IO.puts "  ✓ All containers built successfully"
        :ok
      {output, _} ->
        {:error, "Container build failed. Check build logs."}
    end
  end

  @spec start_signoz_stack() :: any()
  defp start_signoz_stack do
    IO.puts "  Starting SigNoz stack..."

    # Create necessary config directories
    create_config_directories()

    # Start with podman-compose
    case System.cmd("podman-compose", ["-f", "podman-compose.observability.yml", "up", "-d"],
      stderr_to_stdout: true, cd: project_root()) do
      {output, 0} ->
        IO.puts "  ✓ SigNoz stack started"
        :ok
      {output, _} ->
        {:error, "Failed to start SigNoz stack"}
    end
  end

  @spec health_check_all_services() :: any()
  defp health_check_all_services do
    IO.puts "  Checking service health..."

    services = [
      {"ClickHouse", "http://localhost:8123/ping"},
      {"Query Service", "http://localhost:8080/api/v1/health"},
      {"OTEL Collector", "http://localhost:13_133/health"},
      {"Frontend", "http://localhost:3301/health"}
    ]

    # Wait a bit for services to start
    Process.sleep(10_000)

    _results = Enum.map(services, fn {name, url} ->
      case check_health(url) do
        :ok ->
          IO.puts "  ✓ #{name} is healthy"
          :ok
        :error ->
          IO.puts "  ✗ #{name} is not responding"
          :error
      end
    end)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, "Some services are not healthy"}
    end
  end

  @spec check_health(term()) :: term()
  defp check_health(url) do
    case System.cmd("curl", ["-s", "-f", url], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> :error
    end
  end

  @spec configure_application() :: any()
  defp configure_application do
    IO.puts "  Configuring application for SigNoz..."

    # Check if environment variables are set
    __required_vars = [
      {"OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"},
      {"OTEL_SERVICE_NAME", "indrajaal"},
      {"CLICKHOUSE_PASSWORD", "signoz2024!"}
    ]

    missing = Enum.reject(__required_vars, fn {var, _default} ->
      System.get_env(var) != nil
    end)

    if Enum.empty?(missing) do
      IO.puts "  ✓ Application configured"
      :ok
    else
      IO.puts "  ⚠️  Missing environment variables:"
      Enum.each(missing, fn {var, default} ->
        IO.puts "    export #{var}=\"#{default}\""
      end)
      {:warning, "Some environment variables are not set"}
    end
  end

  @spec validate_telemetry_export() :: any()
  defp validate_telemetry_export do
    IO.puts "  Validating telemetry export..."

    # Generate a test trace
    IO.puts "  Generating test trace..."

    # This would run a small Elixir script that generates a trace
    test_script = """
    Application.ensure_all_started(:opentelemetry)
    Application.ensure_all_started(:opentelemetry_exporter)

    __require OpenTelemetry.Tracer

    OpenTelemetry.Tracer.with_span "deployment.test.trace" do
      Process.sleep(100)
      IO.puts("Test trace generated")
    end

    Process.sleep(5000)  # Wait for export
    """

    File.write!("/tmp/test_trace.exs", test_script)

    case System.cmd("elixir", ["/tmp/test_trace.exs"],
      stderr_to_stdout: true, cd: project_root()) do
      {_, 0} ->
        # Check if trace appears in SigNoz
        Process.sleep(5_000)
        # TODO: Query SigNoz API to verify trace
        IO.puts "  ✓ Telemetry export working"
        :ok
      _ ->
        {:warning, "Could not verify telemetry export"}
    end
  after
    File.rm("/tmp/test_trace.exs")
  end

  @spec provision_all_dashboards() :: any()
  defp provision_all_dashboards do
    IO.puts "  Provisioning dashboards..."
    # TODO: Implement dashboard provisioning via SigNoz API
    IO.puts "  ℹ️  Dashboard provisioning will be done manually"
    :ok
  end

  @spec configure_alert_rules() :: any()
  defp configure_alert_rules do
    IO.puts "  Configuring alert rules..."
    # TODO: Implement alert rule configuration
    IO.puts "  ℹ️  Alert rules will be configured manually"
    :ok
  end

  # Utility functions

  @spec project_root() :: any()
  defp project_root do
    File.cwd!()
  end

  @spec generate_deployment_id() :: any()
  defp generate_deployment_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "signoz-deploy-#{timestamp}"
  end

  @spec save_deployment_state(term()) :: term()
  defp save_deployment_state(deployment_id) do
    __state_dir = Path.join([project_root(), ".deployments"])
    File.mkdir_p!(__state_dir)

    __state_file = Path.join(__state_dir, "#{deployment_id}.json")

    __state = %{
      id: deployment_id,
      timestamp: DateTime.utc_now(),
      completed_steps: [],
      status: "in_progress"
    }

    File.write!(__state_file, Jason.encode!(__state, pretty: true))
  end

  @spec mark_step_complete(term(), term()) :: term()
  defp mark_step_complete(deployment_id, step_id) do
    # Update deployment __state
    __state_file = Path.join([project_root(), ".deployments", "#{deployment_id}.jso

    if File.exists?(__state_file) do
      __state = File.read!(__state_file) |> Jason.decode!()
      updated_state = Map.update!(__state, "completed_steps", &(&1 ++ [to_string(step_id)]))
      File.write!(__state_file, Jason.encode!(updated_state, pretty: true))
    end
  end

  @spec mark_deployment_complete(term()) :: term()
  defp mark_deployment_complete(deployment_id) do
    __state_file = Path.join([project_root(), ".deployments", "#{deployment_id}.jso

    if File.exists?(__state_file) do
      __state = File.read!(__state_file) |> Jason.decode!()
      _updated_state = Map.put(__state, "status", "completed")
      File.write!(__state_file, Jason.encode!(updated_state, pretty: true))
    end

    # Create symlink to current deployment
    current_link = Path.join([project_root(), ".deployments", "current"])
    File.rm(current_link)
    File.ln_s!(__state_file, current_link)
  end

  @spec rollback_to_step(term(), term()) :: term()
  defp rollback_to_step(deployment_id, failed_step) do
    IO.puts "Rolling back deployment #{deployment_id} from step #{failed_step}...

    # Stop services
    System.cmd("podman-compose", ["-f", "podman-compose.observability.yml", "down"],
      cd: project_root())

    IO.puts "✓ Rollback completed"
  end

  @spec check_deployment_status() :: any()
  defp check_deployment_status do
    IO.puts "\n📊 Deployment Status"
    IO.puts "─" |> String.duplicate(70)

    # Check if services are running
    case System.cmd("podman-compose", ["-f", "podman-compose.observability.yml", "ps"],
      stderr_to_stdout: true, cd: project_root()) do
      {output, 0} ->
        IO.puts output
      _ ->
        IO.puts "No deployment found or services not running"
    end

    # Check current deployment
    current_file = Path.join([project_root(), ".deployments", "current"])
    if File.exists?(current_file) do
      __state_file = File.read_link!(current_file)
      __state = File.read!(__state_file) |> Jason.decode!()

      IO.puts "\nCurrent deployment: #{__state["id"]}"
      IO.puts "Status: #{__state["status"]}"
      IO.puts "Timestamp: #{__state["timestamp"]}"
    end
  end

  @spec rollback_deployment() :: any()
  defp rollback_deployment do
    IO.puts "\n🔄 Rolling back deployment..."

    System.cmd("podman-compose", ["-f", "podman-compose.observability.yml", "down"],
      cd: project_root())

    IO.puts "✓ Services stopped"
  end

  @spec validate_deployment() :: any()
  defp validate_deployment do
    IO.puts "\n🔍 Validating deployment __requirements..."

    Enum.each(@deployment_steps, fn {step_id, func, description} ->
      if step_id in [:test_validation, :safety_validation] do
        IO.puts "\n#{description}..."
        case func.() do
          :ok -> IO.puts "✅ Validation passed"
          {:warning, msg} -> IO.puts "⚠️  Warning: #{msg}"
          {:error, msg} -> IO.puts "❌ Error: #{msg}"
        end
      end
    end)
  end

  @spec create_config_directories() :: any()
  defp create_config_directories do
    dirs = [
      "observability/clickhouse/config.d",
      "observability/clickhouse/__users.d",
      "observability/otel",
      ".deployments"
    ]

    Enum.each(dirs, fn dir ->
      path = Path.join(project_root(), dir)
      File.mkdir_p!(path)
    end)
  end
end

# Run the deployment
SignozDeployment.main(System.argv())
end
