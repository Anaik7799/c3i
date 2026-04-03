#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule MixTasksQuickValidator do
  @moduledoc """
  Quick Mix Tasks Validation - Level 2 Focus
  
  Efficiently validates Mix tasks and aliases without module redefinition issues.
  """

  def main(args) do
    case args do
      ["--level", "2"] -> execute_level_2()
      _ -> execute_level_2()
    end
  end

  def execute_level_2 do
    IO.puts("\n🔧 LEVEL 2: Advanced Mix Tasks and Aliases Validation")
    IO.puts("=" <> String.duplicate("=", 60))
    
    start_time = System.monotonic_time(:millisecond)
    
    results = %{
      builtin_tasks: validate_builtin_mix_tasks(),
      custom_aliases: validate_custom_aliases(),
      task_chains: validate_task_chains(),
      alias_complexity: analyze_alias_complexity(),
      task_performance: validate_task_performance()
    }
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    success_count = results |> Map.values() |> Enum.count(& &1.status == :ok)
    total_count = map_size(results)
    success_rate = success_count / total_count * 100
    
    # Save results
    save_level_2_results(results, duration, success_rate)
    
    IO.puts("\n✅ LEVEL 2 COMPLETED in #{duration}ms")
    IO.puts("📊 Success Rate: #{Float.round(success_rate, 1)}%")
    
    %{
      level: 2,
      success_rate: success_rate,
      results: results,
      status: if(success_count >= 3, do: :passed, else: :partial)
    }
  end

  def validate_builtin_mix_tasks do
    IO.puts("\n🛠️ L2.1: Built-in Mix Tasks Validation")
    
    # Critical built-in tasks to test
    critical_tasks = [
      "compile", "test", "deps.get", "format", "credo", "dialyzer"
    ]
    
    results = for task <- critical_tasks do
      test_mix_task_quick(task)
    end
    
    success_count = Enum.count(results, fn {_task, status} -> status == :ok end)
    
    IO.puts("  ✅ Built-in tasks: #{success_count}/#{length(critical_tasks)} working")
    
    %{
      status: if(success_count >= 4, do: :ok, else: :warning),
      results: results,
      total: length(critical_tasks),
      successful: success_count,
      details: "Core Mix tasks validation completed"
    }
  end

  def validate_custom_aliases do
    IO.puts("\n🔗 L2.2: Custom Aliases Validation")
    
    # Read aliases from mix.exs via file parsing
    aliases = extract_aliases_from_file()
    
    IO.puts("  📋 Found #{length(aliases)} custom aliases")
    
    # Test a sample of aliases for performance
    sample_aliases = Enum.take(aliases, 10)
    results = for {alias_name, _commands} <- sample_aliases do
      test_alias_quick(alias_name)
    end
    
    success_count = Enum.count(results, fn {_alias, status} -> status == :ok end)
    
    %{
      status: if(success_count >= length(sample_aliases) * 0.6, do: :ok, else: :warning),
      total_aliases: length(aliases),
      tested_aliases: length(sample_aliases),
      successful: success_count,
      details: "Custom aliases: #{success_count}/#{length(sample_aliases)} tested successfully"
    }
  end

  def validate_task_chains do
    IO.puts("\n⛓️ L2.3: Task Chains Validation")
    
    # Test important task chains
    important_chains = [
      "setup", "quality", "precommit", "test.comprehensive"
    ]
    
    results = for chain <- important_chains do
      test_task_chain_quick(chain)
    end
    
    success_count = Enum.count(results, fn {_chain, status} -> status == :ok end)
    
    %{
      status: if(success_count >= 2, do: :ok, else: :warning),
      results: results,
      successful: success_count,
      details: "Task chains: #{success_count}/#{length(important_chains)} validated"
    }
  end

  def analyze_alias_complexity do
    IO.puts("\n📊 L2.4: Alias Complexity Analysis")
    
    aliases = extract_aliases_from_file()
    
    # Analyze complexity
    complexity_analysis = for {alias_name, commands} <- aliases do
      complexity = calculate_alias_complexity(commands)
      {alias_name, complexity}
    end
    
    # Categorize by complexity
    simple = Enum.count(complexity_analysis, fn {_name, complexity} -> complexity <= 2 end)
    moderate = Enum.count(complexity_analysis, fn {_name, complexity} -> complexity > 2 and complexity <= 5 end)
    complex = Enum.count(complexity_analysis, fn {_name, complexity} -> complexity > 5 end)
    
    IO.puts("  📈 Complexity Distribution:")
    IO.puts("    - Simple (≤2 commands): #{simple}")
    IO.puts("    - Moderate (3-5 commands): #{moderate}")
    IO.puts("    - Complex (>5 commands): #{complex}")
    
    # STAMP hazard analysis
    stamp_status = if complex > length(aliases) * 0.3 do
      :warning  # High complexity could be a STAMP hazard
    else
      :ok
    end
    
    %{
      status: stamp_status,
      total_aliases: length(aliases),
      simple: simple,
      moderate: moderate,
      complex: complex,
      stamp_hazard: complex > length(aliases) * 0.3,
      details: "Alias complexity analyzed - #{complex} complex aliases detected"
    }
  end

  def validate_task_performance do
    IO.puts("\n⚡ L2.5: Task Performance Validation")
    
    # Test performance of key tasks
    performance_tests = [
      {"compile --help", "Compile help response time"},
      {"test --help", "Test help response time"},
      {"deps.get --help", "Deps help response time"}
    ]
    
    results = for {task, description} <- performance_tests do
      measure_task_performance(task, description)
    end
    
    avg_time = results 
    |> Enum.map(fn {_task, time} -> time end) 
    |> Enum.sum() 
    |> div(length(results))
    
    performance_status = if avg_time < 1000, do: :ok, else: :warning
    
    %{
      status: performance_status,
      results: results,
      average_time_ms: avg_time,
      details: "Task performance: #{avg_time}ms average response time"
    }
  end

  # Helper functions
  def test_mix_task_quick(task) do
    case System.cmd("mix", ["help", task], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 -> {task, :ok}
      _ -> {task, :not_available}
    end
  rescue
    _ -> {task, :error}
  end

  def test_alias_quick(alias_name) do
    case System.cmd("mix", ["help", to_string(alias_name)], stderr_to_stdout: true) do
      {_output, 0} -> {alias_name, :ok}
      _ -> {alias_name, :not_available}
    end
  rescue
    _ -> {alias_name, :error}
  end

  def test_task_chain_quick(chain) do
    case System.cmd("mix", ["help", chain], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 -> {chain, :ok}
      _ -> {chain, :not_available}
    end
  rescue
    _ -> {chain, :error}
  end

  def extract_aliases_from_file do
    case File.read("mix.exs") do
      {:ok, content} ->
        # Extract aliases using simple regex
        case Regex.run(~r/aliases:\s*\[([^\]]+)\]/s, content) do
          [_, aliases_content] ->
            parse_aliases_content(aliases_content)
          _ -> []
        end
      _ -> []
    end
  end

  def parse_aliases_content(content) do
    # Simple parsing of alias definitions
    lines = String.split(content, "\n")
    
    aliases = for line <- lines do
      case Regex.run(~r/"([^"]+)":\s*\[([^\]]+)\]/, line) do
        [_, alias_name, commands] ->
          command_list = String.split(commands, ",") |> Enum.map(&String.trim/1)
          {alias_name, command_list}
        _ ->
          case Regex.run(~r/"([^"]+)":\s*"([^"]+)"/, line) do
            [_, alias_name, command] -> {alias_name, [command]}
            _ -> nil
          end
      end
    end
    
    aliases |> Enum.filter(& &1 != nil)
  end

  def calculate_alias_complexity(commands) when is_list(commands) do
    # Simple complexity calculation
    length(commands)
  end

  def calculate_alias_complexity(_), do: 1

  def measure_task_performance(task, description) do
    IO.puts("  ⏱️ Testing #{description}")
    
    start_time = System.monotonic_time(:millisecond)
    
    task_parts = String.split(task, " ")
    System.cmd("mix", task_parts, stderr_to_stdout: true)
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    {task, duration}
  rescue
    _ -> {task, 9999}  # High penalty for errors
  end

  def save_level_2_results(results, duration, success_rate) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_path = "./__data/tmp/#{timestamp}-level2-validation-results.log"
    
    content = """
    Mix.exs Level 2 Validation Results
    ==================================
    
    Date: #{DateTime.utc_now() |> DateTime.to_string()}
    Level: 2 - Advanced Mix Tasks and Aliases Validation
    Duration: #{duration}ms
    Success Rate: #{Float.round(success_rate, 1)}%
    Status: #{if success_rate >= 70, do: "PASSED", else: "PARTIAL"}
    
    DETAILED RESULTS:
    ================
    
    Built-in Tasks: #{inspect(results.builtin_tasks)}
    
    Custom Aliases: #{inspect(results.custom_aliases)}
    
    Task Chains: #{inspect(results.task_chains)}
    
    Alias Complexity: #{inspect(results.alias_complexity)}
    
    Task Performance: #{inspect(results.task_performance)}
    
    RECOMMENDATIONS:
    ================
    
    #{generate_level_2_recommendations(results)}
    """
    
    File.write!(log_path, content)
    IO.puts("\n📄 Level 2 results saved to: #{log_path}")
  end

  def generate_level_2_recommendations(results) do
    recommendations = []
    
    recommendations = if results.builtin_tasks.status != :ok do
      ["- Install missing Mix tasks (credo, dialyzer, etc.)" | recommendations]
    else
      recommendations
    end
    
    recommendations = if results.alias_complexity.stamp_hazard do
      ["- STAMP HAZARD: Reduce alias complexity to improve maintainability" | recommendations]
    else
      recommendations
    end
    
    recommendations = if results.task_performance.average_time_ms > 1000 do
      ["- Optimize task performance - average response time too high" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      "All Level 2 validations passed successfully!"
    else
      Enum.join(recommendations, "\n")
    end
  end
end

# Execute Level 2
MixTasksQuickValidator.main(System.argv())