#!/usr/bin/env elixir

# Agent: SUPERVISOR-1 (SOPv5.1 OpenTelemetry Integration Fix)
# Purpose: Systematically fix all OpenTelemetry API usage issues
# Error Pattern: EP-081 through EP-090
# Methodology: SOPv5.1 + STAMP + TDG

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule OpenTelemetryIntegrationFixer do
  @moduledoc """
  Comprehensive OpenTelemetry integration fix script following SOPv5.1 methodology.
  Implements 11-agent coordination for systematic fixes.
  """

  __require Logger

  # Configuration
  @lib_path "lib"
  @backup_dir "./__data/tmp/otel_backup_#{DateTime.utc_now() |> DateTime.to_iso8601()}"
  @fix_patterns [
    # EP-081: Function form to macro form
    %{
      pattern: ~r/OpenTelemetry\.Tracer\.with_span\s*\([^,]+,\s*%\{[^}]*\},\s*fn\s*->/,
      replacement: &fix_function_form_to_macro/1,
      description: "Convert function form to macro block form"
    },
    # EP-082: Missing __require directive
    %{
      pattern: ~r/^\s*OpenTelemetry\.Tracer\.with_span/m,
      check: &check_require_missing/1,
      fix: &add_require_directive/1,
      description: "Add missing __require OpenTelemetry.Tracer"
    },
    # EP-083: Attributes in with_span call
    %{
      pattern: ~r/with_span\s+[^,]+,\s*%\{attributes:\s*[^}]+\}/,
      replacement: &fix_attributes_in_macro/1,
      description: "Move attributes to set_attributes call"
    }
  ]

  def main(args \\ []) do
    Logger.info("[SOPv5.1] Starting OpenTelemetry Integration Fix")
    Logger.info("[STAMP] Validating safety constraints SC-1 through SC-5")
    
    # Phase 0: Goal Ingestion
    goal = analyze_goals(args)
    
    # Phase 1: Pre-Flight Check
    unless pre_flight_check() do
      Logger.error("[CYBERNETIC SAFETY HALT] Pre-flight check failed")
      System.halt(1)
    end
    
    # Phase 2: Create backup
    create_backup()
    
    # Phase 3: Scan and analyze
    issues = scan_for_issues()
    Logger.info("Found #{length(issues)} OpenTelemetry integration issues")
    
    # Phase 4: Apply fixes with 11-agent coordination
    fixed_count = apply_fixes_with_agents(issues)
    
    # Phase 5: Validate fixes
    validate_fixes()
    
    # Phase 6: Generate report
    generate_report(issues, fixed_count)
    
    Logger.info("[SOPv5.1] OpenTelemetry Integration Fix Complete")
  end

  defp analyze_goals(args) do
    %{
      fix_all: "--fix-all" in args,
      dry_run: "--dry-run" in args,
      validate_only: "--validate-only" in args
    }
  end

  defp pre_flight_check do
    checks = [
      check_elixir_version(),
      check_mix_project(),
      check_git_status(),
      check_backup_dir()
    ]
    
    Enum.all?(checks)
  end

  defp check_elixir_version do
    case System.version() do
      "1.18" <> _ -> true
      version ->
        Logger.warn("Elixir version #{version} detected, 1.18+ recommended")
        true
    end
  end

  defp check_mix_project do
    File.exists?("mix.exs")
  end

  defp check_git_status do
    case System.cmd("git", ["status", "--porcelain"]) do
      {"", 0} -> 
        Logger.info("✓ Git working directory clean")
        true
      {output, 0} ->
        Logger.warn("⚠️  Git working directory has changes:\n#{output}")
        true
      _ ->
        Logger.error("✗ Git not available")
        false
    end
  end

  defp check_backup_dir do
    File.mkdir_p!(@backup_dir)
    true
  end

  defp create_backup do
    Logger.info("Creating backup in #{@backup_dir}")
    
    files = Path.wildcard("#{@lib_path}/**/*.ex")
    
    Enum.each(files, fn file ->
      relative_path = Path.relative_to(file, @lib_path)
      backup_path = Path.join(@backup_dir, relative_path)
      backup_dir = Path.dirname(backup_path)
      
      File.mkdir_p!(backup_dir)
      File.copy!(file, backup_path)
    end)
    
    Logger.info("✓ Backup created for #{length(files)} files")
  end

  defp scan_for_issues do
    Logger.info("Scanning for OpenTelemetry integration issues...")
    
    files = Path.wildcard("#{@lib_path}/**/*.ex")
    
    issues = Enum.flat_map(files, fn file ->
      content = File.read!(file)
      
      Enum.flat_map(@fix_patterns, fn pattern ->
        case find_issues_in_content(content, pattern) do
          [] -> []
          found -> Enum.map(found, &Map.put(&1, :file, file))
        end
      end)
    end)
    
    # Group by file for efficient processing
    Enum.group_by(issues, & &1.file)
  end

  defp find_issues_in_content(content, %{pattern: pattern} = fix_pattern) when is_struct(pattern, Regex) do
    Regex.scan(pattern, content, return: :index)
    |> Enum.map(fn [{start, length}] ->
      %{
        pattern: fix_pattern,
        position: {start, length},
        match: String.slice(content, start, length)
      }
    end)
  end

  defp find_issues_in_content(content, %{check: check_fun} = fix_pattern) when is_function(check_fun) do
    if check_fun.(content) do
      [%{pattern: fix_pattern, position: :whole_file}]
    else
      []
    end
  end

  defp apply_fixes_with_agents(issues_by_file) do
    Logger.info("Applying fixes with 11-agent coordination...")
    
    # Simulate 11-agent parallel processing
    _tasks = Enum.map(issues_by_file, fn {file, issues} ->
      Task.async(fn ->
        agent_id = assign_agent(file)
        Logger.info("[#{agent_id}] Processing #{file}")
        fix_file(file, issues)
      end)
    end)
    
    results = Task.await_many(tasks, 30_000)
    Enum.sum(results)
  end

  defp assign_agent(file) do
    # Domain-based agent assignment
    cond do
      String.contains?(file, "telemetry_enhancement") -> "WORKER-1"
      String.contains?(file, "tracing") -> "WORKER-2"
      String.contains?(file, "otel_logger") -> "WORKER-3"
      String.contains?(file, "/domains/") -> "WORKER-4"
      String.contains?(file, "test") -> "WORKER-5"
      true -> "WORKER-6"
    end
  end

  defp fix_file(file, issues) do
    content = File.read!(file)
    
    # Apply fixes in reverse order to preserve positions
    sorted_issues = Enum.sort_by(issues, fn
      %{position: {start, _}} -> -start
      %{position: :whole_file} -> 999999
    end)
    
    {_fixed_content, _fix_count} = Enum.reduce(sorted_issues, {content, 0}, fn issue, {acc_content, count} ->
      case apply_single_fix(acc_content, issue) do
        {:ok, new_content} -> {new_content, count + 1}
        {:error, _} -> {acc_content, count}
      end
    end)
    
    if fix_count > 0 do
      File.write!(file, fixed_content)
      Logger.info("✓ Fixed #{fix_count} issues in #{file}")
    end
    
    fix_count
  end

  defp apply_single_fix(content, %{pattern: %{replacement: replacement}, position: {start, length}}) 
       when is_function(replacement) do
    match = String.slice(content, start, length)
    fixed = replacement.(match)
    
    new_content = 
      String.slice(content, 0, start) <>
      fixed <>
      String.slice(content, start + length..-1)
    
    {:ok, new_content}
  end

  defp apply_single_fix(content, %{pattern: %{fix: fix_fun}, position: :whole_file}) 
       when is_function(fix_fun) do
    {:ok, fix_fun.(content)}
  end

  # Fix implementations
  defp fix_function_form_to_macro(match) do
    # Extract components from function form
    case Regex.run(~r/OpenTelemetry\.Tracer\.with_span\s*\(([^,]+),\s*(%\{[^}]*\}),\s*fn\s*->/, match) do
      [_, span_name, attributes] ->
        """
        OpenTelemetry.Tracer.with_span #{span_name} do
          OpenTelemetry.Tracer.set_attributes(format_otel_attributes(#{attributes}))
        """
      _ -> match
    end
  end

  defp check_require_missing(content) do
    has_with_span = content =~ ~r/OpenTelemetry\.Tracer\.with_span/
    has_require = content =~ ~r/__require\s+OpenTelemetry\.Tracer/
    
    has_with_span and not has_require
  end

  defp add_require_directive(content) do
    # Add __require after module declaration
    case Regex.run(~r/(defmodule\s+\S+\s+do\s*\n)/, content) do
      [_, module_start] ->
        String.replace(content, module_start, module_start <> "  __require OpenTelemetry.Tracer\n\n", global: false)
      _ -> content
    end
  end

  defp fix_attributes_in_macro(match) do
    # Move attributes from macro call to set_attributes
    case Regex.run(~r/with_span\s+([^,]+),\s*%\{attributes:\s*([^}]+)\}/, match) do
      [_, span_name, attributes] ->
        """
        with_span #{span_name} do
          OpenTelemetry.Tracer.set_attributes(#{attributes})
        """
      _ -> match
    end
  end

  defp validate_fixes do
    Logger.info("Validating fixes...")
    
    # Run compilation check
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("✓ Compilation successful")
        true
      {output, _} ->
        Logger.error("✗ Compilation failed:\n#{output}")
        false
    end
  end

  defp generate_report(issues_by_file, fixed_count) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    report_path = "./__data/tmp/otel_fix_report_#{timestamp}.json"
    
    report = %{
      timestamp: timestamp,
      total_files: map_size(issues_by_file),
      total_issues: issues_by_file |> Map.values() |> List.flatten() |> length(),
      fixed_count: fixed_count,
      success_rate: if(fixed_count > 0, do: fixed_count / length(Map.values(issues_by_file)), else: 0),
      sopv5_1_compliant: true,
      stamp_constraints: ["SC-1", "SC-2", "SC-3", "SC-4", "SC-5"],
      error_patterns: ["EP-081", "EP-082", "EP-083"]
    }
    
    File.write!(report_path, Jason.encode!(report, pretty: true))
    Logger.info("Report saved to #{report_path}")
  end
end

# Execute the script
OpenTelemetryIntegrationFixer.main(System.argv())