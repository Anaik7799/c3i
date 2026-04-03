#!/usr/bin/env elixir

Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

defmodule ObservabilityValidator do
  @moduledoc """
  Comprehensive validation script for observability implementation.
  Checks modules, configuration, and basic functionality without full app startup.
  """

  def main(_args \\ []) do
    IO.puts("\n🔍 Indrajaal Observability Implementation Validator")
    IO.puts("=" |> String.duplicate(60))

    results = [
      validate_modules(),
      validate_configuration(),
      validate_trace_context(),
      validate_logging(),
      validate_domain_instrumentation(),
      validate_dashboards(),
      validate_telemetry_handlers()
    ]

    print_summary(results)
  end

  defp validate_modules do
    IO.puts("\n📦 Validating Core Observability Modules...")

    modules = [
      {Indrajaal.Observability.DualLogging, "lib/indrajaal/observability/dual_logging.ex"},
      {Indrajaal.Observability.Tracing, "lib/indrajaal/observability/tracing.ex"},
      {Indrajaal.Observability.Telemetry, "lib/indrajaal/observability/telemetry.ex"},
      {Indrajaal.Observability.Domains.Alarms, "lib/indrajaal/observability/domains/alarms.ex"},
      {Indrajaal.Observability.Domains.Accounts,
       "lib/indrajaal/observability/domains/accounts.ex"},
      {Indrajaal.Observability.Domains.Analytics,
       "lib/indrajaal/observability/domains/analytics.ex"},
      {Indrajaal.Observability.Domains.Devices, "lib/indrajaal/observability/domains/devices.ex"},
      {Indrajaal.Observability.Domains.Sites, "lib/indrajaal/observability/domains/sites.ex"},
      {Indrajaal.Observability.Domains.Communication,
       "lib/indrajaal/observability/domains/communication.ex"},
      {Indrajaal.Observability.Domains.Compliance,
       "lib/indrajaal/observability/domains/compliance.ex"},
      {Indrajaal.Observability.Domains.GuardTours,
       "lib/indrajaal/observability/domains/guard_tours.ex"},
      {Indrajaal.Observability.Domains.Integration,
       "lib/indrajaal/observability/domains/integration.ex"},
      {Indrajaal.Observability.Domains.Intelligence,
       "lib/indrajaal/observability/domains/intelligence.ex"},
      {Indrajaal.Observability.Domains.Maintenance,
       "lib/indrajaal/observability/domains/maintenance.ex"},
      {Indrajaal.Observability.Domains.Shifts, "lib/indrajaal/observability/domains/shifts.ex"},
      {Indrajaal.Observability.Domains.Training,
       "lib/indrajaal/observability/domains/training.ex"},
      {Indrajaal.Observability.Domains.Video, "lib/indrajaal/observability/domains/video.ex"},
      {Indrajaal.Observability.Domains.VisitorManagement,
       "lib/indrajaal/observability/domains/visitor_management.ex"},
      {Indrajaal.Observability.Domains.EnergyManagement,
       "lib/indrajaal/observability/domains/energy_management.ex"},
      {Indrajaal.Observability.Domains.Environmental,
       "lib/indrajaal/observability/domains/environmental.ex"},
      {Indrajaal.Observability.Domains.FleetManagement,
       "lib/indrajaal/observability/domains/fleet_management.ex"},
      {Indrajaal.Observability.Domains.AccessControl,
       "lib/indrajaal/observability/domains/access_control.ex"}
    ]

    _results =
      Enum.map(modules, fn {module, path} ->
        if File.exists?(path) do
          case compile_module(path) do
            {:ok, _} ->
              IO.puts("  ✅ #{inspect(module)} - exists and compiles")
              {:ok, module}

            {:error, reason} ->
              IO.puts("  ❌ #{inspect(module)} - compilation error: #{reason}")
              {:error, {module, reason}}
          end
        else
          IO.puts("  ❌ #{inspect(module)} - file not found at #{path}")
          {:error, {module, :not_found}}
        end
      end)

    {:modules, results}
  end

  defp validate_configuration do
    IO.puts("\n⚙️  Validating Configuration...")

    config_files = [
      {"config/config.exs", ~r/config :logger.*backends.*\[:console, LoggerJSON\]/s},
      {"config/config.exs", ~r/config :logger_json/},
      {"config/runtime.exs", ~r/config :opentelemetry/},
      {"config/runtime.exs", ~r/otel_exporter_otlp_endpoint/}
    ]

    _results =
      Enum.map(config_files, fn {file, pattern} ->
        if File.exists?(file) do
          content = File.read!(file)

          if Regex.match?(pattern, content) do
            IO.puts("  ✅ #{file} - __required configuration found")
            {:ok, file}
          else
            IO.puts("  ❌ #{file} - missing __required configuration pattern")
            {:error, {file, :missing_config}}
          end
        else
          IO.puts("  ❌ #{file} - file not found")
          {:error, {file, :not_found}}
        end
      end)

    {:configuration, results}
  end

  defp validate_trace_context do
    IO.puts("\n🔗 Validating Trace Context Implementation...")

    # Check if trace __context module exists and has __required functions
    trace_module_path = "lib/indrajaal/observability/tracing.ex"

    if File.exists?(trace_module_path) do
      content = File.read!(trace_module_path)

      __required_functions = [
        "inject_context",
        "extract_context",
        "get_trace_id",
        "start_span",
        "end_span"
      ]

      _results =
        Enum.map(__required_functions, fn func ->
          if String.contains?(content, "def #{func}") do
            IO.puts("  ✅ Function #{func}/1 found")
            {:ok, func}
          else
            IO.puts("  ❌ Function #{func}/1 not found")
            {:error, func}
          end
        end)

      {:trace_context, results}
    else
      IO.puts("  ❌ Tracing module not found")
      {:trace_context, [{:error, :module_not_found}]}
    end
  end

  defp validate_logging do
    IO.puts("\n📝 Validating Dual Logging Setup...")

    dual_logging_path = "lib/indrajaal/observability/dual_logging.ex"

    if File.exists?(dual_logging_path) do
      content = File.read!(dual_logging_path)

      checks = [
        {"validate_dual_logging!", ~r/def validate_dual_logging!/},
        {"log_domain_event", ~r/def log_domain_event/},
        {"log_important", ~r/def log_important/},
        {"Logger backend check", ~r/Application\.get_env\(:logger, :backends\)/}
      ]

      _results =
        Enum.map(checks, fn {name, pattern} ->
          if Regex.match?(pattern, content) do
            IO.puts("  ✅ #{name} implemented")
            {:ok, name}
          else
            IO.puts("  ❌ #{name} not found")
            {:error, name}
          end
        end)

      {:logging, results}
    else
      IO.puts("  ❌ DualLogging module not found")
      {:logging, [{:error, :module_not_found}]}
    end
  end

  defp validate_domain_instrumentation do
    IO.puts("\n🎯 Validating Domain Instrumentation...")

    domains = [
      "alarms",
      "accounts",
      "analytics",
      "devices",
      "sites",
      "communication",
      "compliance",
      "guard_tours",
      "integration",
      "intelligence",
      "maintenance",
      "shifts",
      "training",
      "video",
      "visitor_management",
      "energy_management",
      "environmental",
      "fleet_management",
      "access_control"
    ]

    _results =
      Enum.map(domains, fn domain ->
        module_path = "lib/indrajaal/observability/domains/#{domain}.ex"

        if File.exists?(module_path) do
          content = File.read!(module_path)

          # Check for telemetry __events
          has_telemetry = Regex.match?(~r/:telemetry\.execute/, content)
          has_setup = Regex.match?(~r/def setup/, content)

          if has_telemetry && has_setup do
            IO.puts("  ✅ #{domain} - properly instrumented")
            {:ok, domain}
          else
            missing = []
            missing = if !has_telemetry, do: ["telemetry __events" | missing], else: missing
            missing = if !has_setup, do: ["setup function" | missing], else: missing
            IO.puts("  ⚠️  #{domain} - missing: #{Enum.join(missing, ", ")}")
            {:warning, {domain, missing}}
          end
        else
          IO.puts("  ❌ #{domain} - instrumentation module not found")
          {:error, {domain, :not_found}}
        end
      end)

    {:domain_instrumentation, results}
  end

  defp validate_dashboards do
    IO.puts("\n📊 Validating Dashboard Configurations...")

    dashboard_dir = "scripts/observability/dashboards"

    if File.exists?(dashboard_dir) do
      dashboard_files =
        File.ls!(dashboard_dir)
        |> Enum.filter(&String.ends_with?(&1, ".exs"))

      if length(dashboard_files) > 0 do
        _results =
          Enum.map(dashboard_files, fn file ->
            path = Path.join(dashboard_dir, file)
            IO.puts("  ✅ Found dashboard script: #{file}")
            {:ok, file}
          end)

        # Check for dashboard creator script
        creator_path = Path.join(dashboard_dir, "create_signoz_dashboards.exs")

        if File.exists?(creator_path) do
          IO.puts("  ✅ Dashboard creator script found")
        else
          IO.puts("  ⚠️  Dashboard creator script not found at expected location")
        end

        {:dashboards, results}
      else
        IO.puts("  ❌ No dashboard scripts found in #{dashboard_dir}")
        {:dashboards, [{:error, :no_dashboards}]}
      end
    else
      IO.puts("  ❌ Dashboard directory not found: #{dashboard_dir}")
      {:dashboards, [{:error, :directory_not_found}]}
    end
  end

  defp validate_telemetry_handlers do
    IO.puts("\n📡 Validating Telemetry Handlers...")

    telemetry_path = "lib/indrajaal/observability/telemetry.ex"

    if File.exists?(telemetry_path) do
      content = File.read!(telemetry_path)

      # Check for handler attachments
      handlers = [
        "http.__request",
        "phoenix.router_dispatch",
        "phoenix.endpoint",
        "ecto.query",
        "oban.job",
        "domain."
      ]

      _results =
        Enum.map(handlers, fn handler ->
          if String.contains?(content, handler) do
            IO.puts("  ✅ Handler for #{handler}* __events found")
            {:ok, handler}
          else
            IO.puts("  ⚠️  Handler for #{handler}* __events not found")
            {:warning, handler}
          end
        end)

      {:telemetry_handlers, results}
    else
      IO.puts("  ❌ Telemetry module not found")
      {:telemetry_handlers, [{:error, :module_not_found}]}
    end
  end

  defp compile_module(path) do
    try do
      Code.compile_file(path)
      {:ok, path}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp print_summary(results) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📋 VALIDATION SUMMARY")
    IO.puts(String.duplicate("=", 60))

    {total, passed, warnings, failed} =
      Enum.reduce(results, {0, 0, 0, 0}, fn {category, checks}, {t, p, w, f} ->
        {cat_total, cat_passed, cat_warnings, cat_failed} = count_results(checks)

        status =
          cond do
            cat_failed > 0 -> "❌ FAILED"
            cat_warnings > 0 -> "⚠️  WARNING"
            true -> "✅ PASSED"
          end

        IO.puts("\n#{status} #{format_category(category)}:")

        IO.puts(
          "  Total: #{cat_total}, Passed: #{cat_passed}, Warnings: #{cat_warnings}, Failed: #{cat_failed}"
        )

        {t + cat_total, p + cat_passed, w + cat_warnings, f + cat_failed}
      end)

    IO.puts("\n" <> String.duplicate("-", 60))

    IO.puts(
      "OVERALL: Total: #{total}, Passed: #{passed}, Warnings: #{warnings}, Failed: #{failed}"
    )

    success_rate = if total > 0, do: Float.round(passed / total * 100, 1), else: 0

    IO.puts("\nSuccess Rate: #{success_rate}%")

    cond do
      failed == 0 && warnings == 0 ->
        IO.puts("\n✅ All observability components are properly implemented!")

      failed == 0 ->
        IO.puts("\n⚠️  Implementation is functional but has warnings that should be addressed.")

      true ->
        IO.puts("\n❌ Critical issues found. Please fix the failures before proceeding.")
    end

    IO.puts("\n💡 Next Steps:")

    if failed > 0 do
      IO.puts("  1. Fix compilation errors and missing modules")
      IO.puts("  2. Ensure all configuration is properly set")
      IO.puts("  3. Implement missing instrumentation functions")
    else
      IO.puts("  1. Start the application with proper environment variables:")
      IO.puts("     OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 mix phx.server")
      IO.puts("  2. Verify SigNoz is receiving traces and logs")
      IO.puts("  3. Create custom dashboards for your domains")
    end
  end

  defp count_results(checks) do
    Enum.reduce(checks, {0, 0, 0, 0}, fn result, {total, passed, warnings, failed} ->
      case result do
        {:ok, _} -> {total + 1, passed + 1, warnings, failed}
        {:warning, _} -> {total + 1, passed, warnings + 1, failed}
        {:error, _} -> {total + 1, passed, warnings, failed + 1}
      end
    end)
  end

  defp format_category(category) do
    category
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

# Run the validator
ObservabilityValidator.main(System.argv())
