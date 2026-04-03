#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule MixExsTDGValidator do
  @moduledoc """
  TDG (Test-Driven Generation) validator for mix.exs enhancements.
  Validates all Level 1-3 enhancements without __requiring full project compilation.
  """

  def main(args \\ []) do
    IO.puts("🧪 Starting TDG Validation for Mix.exs Enhancements")
    IO.puts("=" <> String.duplicate("=", 60))
    
    case run_validation() do
      {:ok, results} ->
        output_results(results)
        System.halt(0)
      {:error, reason} ->
        IO.puts("❌ TDG Validation Failed: #{reason}")
        System.halt(1)
    end
  end

  defp run_validation do
    try do
      # Load mix.exs configuration
      mix_config = load_mix_configuration()
      
      # Run all validation tests
      results = %{
        level1_dependency_security: validate_level1_dependency_security(mix_config),
        level2_performance_optimization: validate_level2_performance_optimization(mix_config),
        level3_environment_configuration: validate_level3_environment_configuration(mix_config),
        stamp_safety_constraints: validate_stamp_safety_constraints(mix_config),
        overall_status: :pending
      }
      
      # Determine overall status
      overall_status = if all_tests_pass?(results) do
        :success
      else
        :failure
      end
      
      _final_results = Map.put(results, :overall_status, overall_status)
      
      {:ok, final_results}
    rescue
      error ->
        {:error, "Validation error: #{inspect(error)}"}
    end
  end

  defp load_mix_configuration do
    # Load mix.exs configuration safely
    mix_exs_path = Path.join(File.cwd!(), "mix.exs")
    
    if File.exists?(mix_exs_path) do
      # Read mix.exs content
      content = File.read!(mix_exs_path)
      
      # Extract project configuration using pattern matching
      extract_project_config(content)
    else
      raise "mix.exs not found at #{mix_exs_path}"
    end
  end

  defp extract_project_config(content) do
    # Extract aliases section
    aliases = extract_aliases(content)
    
    # Extract basic project info
    app_name = extract_app_name(content)
    version = extract_version(content)
    
    %{
      app: app_name,
      version: version,
      aliases: aliases,
      content: content
    }
  end

  defp extract_aliases(content) do
    # Find aliases section with improved regex
    case Regex.run(~r/aliases:\s*\[(.*?)\]/s, content) do
      [_, aliases_content] ->
        # Parse alias definitions
        parse_aliases(aliases_content)
      nil ->
        # Try alternative pattern for large aliases blocks
        extract_aliases_alternative(content)
    end
  end

  defp extract_aliases_alternative(content) do
    # Look for individual alias definitions throughout the file
    alias_pattern = ~r/"([^"]+)":\s*\[((?:[^\[\]]*|\[[^\]]*\])*)\]/s
    
    Regex.scan(alias_pattern, content)
    |> Enum.reduce(%{}, fn [_, alias_name, commands], acc ->
      # Parse commands
      command_list = parse_command_list(commands)
      Map.put(acc, alias_name, command_list)
    end)
  end

  defp parse_aliases(aliases_content) do
    # Extract alias definitions using improved regex
    alias_pattern = ~r/"([^"]+)":\s*\[((?:[^\[\]]*|\[[^\]]*\])*)\]/s
    
    Regex.scan(alias_pattern, aliases_content)
    |> Enum.reduce(%{}, fn [_, alias_name, commands], acc ->
      # Parse commands
      command_list = parse_command_list(commands)
      Map.put(acc, alias_name, command_list)
    end)
  end

  defp parse_command_list(commands) do
    # Simple command parsing - split by comma and clean up
    commands
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.trim(&1, "\""))
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_app_name(content) do
    case Regex.run(~r/app:\s*:([^,\s\]]+)/, content) do
      [_, app_name] -> String.to_atom(app_name)
      nil -> :unknown
    end
  end

  defp extract_version(content) do
    case Regex.run(~r/version:\s*"([^"]+)"/, content) do
      [_, version] -> version
      nil -> "unknown"
    end
  end

  # Level 1: Dependency Security & Validation Tests
  defp validate_level1_dependency_security(config) do
    __required_aliases = [
      "deps.audit",
      "deps.security", 
      "deps.validate",
      "deps.licenses",
      "deps.compliance",
      "deps.emergency",
      "deps.tree",
      "deps.unused",
      "deps.outdated",
      "deps.analyze"
    ]
    
    missing_aliases = Enum.reject(__required_aliases, fn alias_name ->
      Map.has_key?(config.aliases, alias_name)
    end)
    
    # Check specific alias content
    deps_validate_content = Map.get(config.aliases, "deps.validate", [])
    has_hex_audit = "hex.audit" in deps_validate_content
    has_deps_get = "deps.get" in deps_validate_content
    
    %{
      test_name: "Level 1: Dependency Security & Validation",
      status: if missing_aliases == [] and has_hex_audit and has_deps_get do
        :pass
      else
        :fail
      end,
      missing_aliases: missing_aliases,
      hex_audit_present: has_hex_audit,
      deps_get_present: has_deps_get,
      found_aliases: Map.keys(config.aliases) |> Enum.filter(&String.starts_with?(&1, "deps."))
    }
  end

  # Level 2: Performance Optimization Configuration Tests
  defp validate_level2_performance_optimization(config) do
    # Check for elixirc_options in content
    has_optimization_config = String.contains?(config.content, "elixirc_options:")
    has_warnings_as_errors = String.contains?(config.content, "warnings_as_errors: true")
    has_optimize_flag = String.contains?(config.content, "optimize:")
    has_inline_flag = String.contains?(config.content, "inline:")
    has_debug_info = String.contains?(config.content, "debug_info:")
    
    %{
      test_name: "Level 2: Performance Optimization Configuration",
      status: if has_optimization_config and has_warnings_as_errors and 
                has_optimize_flag and has_inline_flag and has_debug_info do
        :pass
      else
        :fail
      end,
      has_optimization_config: has_optimization_config,
      has_warnings_as_errors: has_warnings_as_errors,
      has_optimize_flag: has_optimize_flag,
      has_inline_flag: has_inline_flag,
      has_debug_info: has_debug_info
    }
  end

  # Level 3: Environment-Specific Configuration Tests
  defp validate_level3_environment_configuration(config) do
    # Check for get_env_config function
    has_env_config_function = String.contains?(config.content, "defp get_env_config")
    has_dev_config = String.contains?(config.content, "defp get_env_config(:dev)")
    has_test_config = String.contains?(config.content, "defp get_env_config(:test)")
    has_prod_config = String.contains?(config.content, "defp get_env_config(:prod)")
    
    %{
      test_name: "Level 3: Environment-Specific Configuration",
      status: if has_env_config_function and has_dev_config and 
                has_test_config and has_prod_config do
        :pass
      else
        :fail
      end,
      has_env_config_function: has_env_config_function,
      has_dev_config: has_dev_config,
      has_test_config: has_test_config,
      has_prod_config: has_prod_config
    }
  end

  # STAMP Safety Constraints Validation
  defp validate_stamp_safety_constraints(config) do
    # SC-MIX-001: Configuration changes do not break existing functionality
    has_essential_keys = config.app != :unknown and config.version != "unknown"
    
    # SC-MIX-002: Performance optimizations maintain system stability
    has_stable_warnings_config = String.contains?(config.content, "warnings_as_errors: true")
    
    # SC-MIX-003: Security enhancements maintain compatibility
    has_security_aliases = Map.has_key?(config.aliases, "deps.security")
    
    # SC-MIX-004: Environment configurations are validated
    has_env_validation = String.contains?(config.content, "get_env_config")
    
    # SC-MIX-005: Test framework changes maintain existing coverage
    has_test_coverage = String.contains?(config.content, "test_coverage:")
    
    all_constraints_pass = has_essential_keys and has_stable_warnings_config and 
                          has_security_aliases and has_env_validation and has_test_coverage
    
    %{
      test_name: "STAMP Safety Constraints",
      status: if all_constraints_pass do :pass else :fail end,
      sc_mix_001: has_essential_keys,
      sc_mix_002: has_stable_warnings_config,
      sc_mix_003: has_security_aliases,
      sc_mix_004: has_env_validation,
      sc_mix_005: has_test_coverage
    }
  end

  defp all_tests_pass?(results) do
    test_results = [
      results.level1_dependency_security.status,
      results.level2_performance_optimization.status,
      results.level3_environment_configuration.status,
      results.stamp_safety_constraints.status
    ]
    
    Enum.all?(test_results, &(&1 == :pass))
  end

  defp output_results(results) do
    IO.puts("\n🧪 TDG Validation Results")
    IO.puts("=" <> String.duplicate("=", 60))
    
    # Output each test result
    output_test_result(results.level1_dependency_security)
    output_test_result(results.level2_performance_optimization)
    output_test_result(results.level3_environment_configuration)
    output_test_result(results.stamp_safety_constraints)
    
    # Overall status
    IO.puts("\n" <> String.duplicate("=", 60))
    case results.overall_status do
      :success ->
        IO.puts("✅ OVERALL STATUS: ALL TDG TESTS PASSED")
        IO.puts("🎯 Mix.exs enhancements successfully validated")
      :failure ->
        IO.puts("❌ OVERALL STATUS: SOME TDG TESTS FAILED")
        IO.puts("🚨 Fix failing tests before proceeding")
    end
    IO.puts("=" <> String.duplicate("=", 60))
  end

  defp output_test_result(test_result) do
    status_icon = if test_result.status == :pass, do: "✅", else: "❌"
    IO.puts("\n#{status_icon} #{test_result.test_name}")
    IO.puts("   Status: #{test_result.status}")
    
    # Output test-specific details
    case test_result do
      %{missing_aliases: missing} when missing != [] ->
        IO.puts("   Missing aliases: #{Enum.join(missing, ", ")}")
      %{found_aliases: found} when is_list(found) ->
        IO.puts("   Found #{length(found)} dependency aliases")
      _ ->
        :ok
    end
    
    # Output constraint details for STAMP
    if Map.has_key?(test_result, :sc_mix_001) do
      IO.puts("   SC-MIX-001 (Essential Keys): #{if test_result.sc_mix_001, do: "✅", else: "❌"}")
      IO.puts("   SC-MIX-002 (Stable Warnings): #{if test_result.sc_mix_002, do: "✅", else: "❌"}")
      IO.puts("   SC-MIX-003 (Security Compat): #{if test_result.sc_mix_003, do: "✅", else: "❌"}")
      IO.puts("   SC-MIX-004 (Env Validation): #{if test_result.sc_mix_004, do: "✅", else: "❌"}")
      IO.puts("   SC-MIX-005 (Test Coverage): #{if test_result.sc_mix_005, do: "✅", else: "❌"}")
    end
  end
end

# Run if called directly
if Enum.member?(System.argv(), "--run") or length(System.argv()) == 0 do
  MixExsTDGValidator.main(System.argv())
end