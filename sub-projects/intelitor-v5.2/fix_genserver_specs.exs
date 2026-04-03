#!/usr/bin/env elixir

# Fix incorrect GenServer handle_call specs across all files
# SOPv5.1 systematic approach to fix all handle_call/4 specs to handle_call/3

files_to_fix = [
  "lib/indrajaal/integration/enterprise_api_gateway.ex",
  "lib/indrajaal/telemetry/metrics_collector.ex",
  "lib/indrajaal/alarms/timescaledb_integration.ex",
  "lib/indrajaal/alarms/analytics_dashboard.ex",
  "lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex",
  "lib/indrajaal/observability/compliance_audit.ex",
  "lib/indrajaal/safety/constraint_validator.ex",
  "lib/indrajaal/safety/error_pattern_engine.ex",
  "lib/indrajaal/parallelization/monitoring_dashboard.ex",
  "lib/indrajaal/parallelization/enterprise_integrator.ex",
  "lib/indrajaal/performance/query_optimizer_enhanced.ex",
  "lib/indrajaal/performance/advanced_resource_manager.ex",
  "lib/indrajaal/performance/container_orchestrator.ex",
  "lib/indrajaal/deployment/production_environment_manager.ex",
  "lib/indrajaal/deployment/database_migrator.ex",
  "lib/indrajaal/deployment/acceleration_engine.ex"
]

IO.puts("🔧 Fixing GenServer handle_call specs systematically...")
IO.puts("Files to fix: #{length(files_to_fix)}")

fixed_count = 0

Enum.each(files_to_fix, fn file_path ->
  case File.read(file_path) do
    {:ok, content} ->
      # Fix incorrect handle_call specs with 4 parameters
      new_content =
        String.replace(
          content,
          "@spec handle_call(term(), term(), term(), term()) :: term()",
          "@spec handle_call(term(), term(), term()) :: term()"
        )

      if new_content != content do
        File.write!(file_path, new_content)
        IO.puts("✅ Fixed: #{file_path}")
        fixed_count = fixed_count + 1
      else
        IO.puts("⚠️ No changes needed: #{file_path}")
      end

    {:error, reason} ->
      IO.puts("❌ Error reading #{file_path}: #{reason}")
  end
end)

IO.puts("\n🏁 GenServer spec fixing complete!")
IO.puts("Files fixed: #{fixed_count}/#{length(files_to_fix)}")
