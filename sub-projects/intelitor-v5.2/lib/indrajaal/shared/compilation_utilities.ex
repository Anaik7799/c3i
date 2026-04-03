defmodule Indrajaal.Shared.CompilationUtilities do
  @moduledoc """

  Shared compilation utilities to eliminate code duplication between compilation check modules.

  Extracted from Mix.Tasks.ComprehensiveCompile Check and Comprehensive Compilation Test
  following Toyota TPS principles to eliminate waste and maintain single source of truth.
  """

  @doc """
  Extract and parse warnings from compilation output.

  Returns a list of warning maps with file, line, and message information.
  """
  @spec extract_warnings_from_output(any()) :: any()
  def extract_warnings_from_output(output) when is_binary(output) do
    output
    |> String.split("

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_warning_line/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Parse a single warning line using multiple patterns.

  Returns a warning map or nil if parsing fails.
  """
  @spec parse_warning_line(any()) :: any()
  def parse_warning_line(line) when is_binary(line) do
    # Enhanced warning parsing with multiple patterns
    patterns = [
      # Standard warning pattern with detailed formatting
      ~r/warning: (.+)\s + │\s+(\d+)\s + │.+└─\s+(.+):(\d+):(\d+)/,
      # Alternative standard pattern
      ~r/warning: (.+)\s + │\s+(\d+)\s + │\s+(.+)\s + │\s + └─\s+(.+):(\d+):(\d+)/,
      # Simple warning pattern
      ~r/warning: (.+)\s+\((.+):(\d+)\)/,
      # Basic warning pattern
      ~r/warning: (.+)/
    ]

    parse_with_patterns(line, patterns)
  end

  @doc """
  Parse warning line using a list of regex patterns.

  Tries each pattern in order until one matches.
  """
  @spec parse_with_patterns(any(), any()) :: any()
  def parse_with_patterns(line, [pattern | rest]) when is_binary(line) do
    case Regex.run(pattern, line) do
      nil -> parse_with_patterns(line, rest)
      matches -> format_warning_match(matches)
    end
  end

  @spec parse_with_patterns(any(), any()) :: any()
  def parse_with_patterns(_line, []) do
    nil
  end

  @doc """
  Format regex match results into a standardized warning map.
  """
  @spec format_warning_match(term()) :: term()
  def format_warning_match([_, message, line_num, _code, file, _line2, _col])
      when is_binary(line_num) do
    {line, _} = Integer.parse(line_num)

    %{
      file: String.trim(file),
      line: line,
      message: String.trim(message),
      type: :detailed
    }
  end

  @spec format_warning_match(list()) :: term()
  def format_warning_match([_, message, file, linestr]) do
    {line, _} = Integer.parse(linestr)

    %{
      file: String.trim(file),
      line: line,
      message: String.trim(message),
      type: :simple
    }
  end

  @spec format_warning_match(any()) :: any()
  def format_warning_match([_, message]) do
    %{
      file: "unknown",
      line: 0,
      message: String.trim(message),
      type: :basic
    }
  end

  @spec format_warning_match(any()) :: any()
  def format_warning_match(_) do
    nil
  end

  @doc """
  Categorize warning by its content and type.

  Returns an atom representing the warning category.
  """
  @spec categorize_warning(any()) :: any()
  def categorize_warning(%{message: message}) do
    cond do
      String.contains?(message, "atomic") -> :atomic_warnings
      String.contains?(message, "unused") -> :unused_code
      String.contains?(message, "deprecated") -> :deprecation
      String.contains?(message, "pattern") -> :pattern_match
      String.contains?(message, "spec") -> :typespec
      String.contains?(message, "syntax") -> :syntax
      true -> :general
    end
  end

  @doc """
  Group and analyze warnings by category.

  Returns warnings with category information added.
  """
  @spec analyze_warnings(any()) :: any()
  def analyze_warnings(warnings) when is_list(warnings) do
    # Group warnings by type for analysis
    warnings
    |> Enum.group_by(&categorize_warning/1)
    |> Enum.flat_map(fn {category, warning_list} ->
      warning_list
      |> Enum.map(&Map.put(&1, :category, category))
    end)
  end

  @doc """
  Generate warning statistics for reporting.
  """
  @spec generate_warning_stats(any()) :: any()
  def generate_warning_stats(warnings) when is_list(warnings) do
    total_count = length(warnings)

    by_category =
      warnings
      |> Enum.group_by(&(&1[:category] || :uncategorized))
      |> Enum.map(fn {category, warning_list} ->
        {category, length(warning_list)}
      end)
      |> Map.new()

    by_file =
      warnings
      |> Enum.group_by(&(&1[:file] || "unknown"))
      |> Enum.map(fn {file, warning_list} ->
        {file, length(warning_list)}
      end)
      |> Map.new()

    %{
      total: total_count,
      by_category: by_category,
      by_file: by_file,
      top_files: by_file |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(10)
    }
  end

  @doc """
  Run compilation command with warning capture.

  Returns {output, exit_code} tuple.
  """
  @spec run_compilation_with_warnings_capture(list()) :: any()
  def run_compilation_with_warnings_capture(
        args \\ ["compile", "--warnings-as-errors", "--force"]
      ) do
    System.cmd("mix", args,
      cd: File.cwd!(),
      stderr_to_stdout: true
    )
  end

  @doc """
  Monitor memory usage during a compilation process.

  Returns memory samples collected during the operation.
  """
  @spec monitor_memory_during_compilation(any()) :: any()
  def monitor_memory_during_compilation(operation_fn) do
    # Start a background process to sample memory
    parent = self()

    memory_monitor =
      spawn(fn ->
        monitor_memory_loop(parent, [])
      end)

    start_time = System.monotonic_time(:millisecond)
    start_memory = :erlang.memory(:total)

    try do
      result = operation_fn.()
      end_time = System.monotonic_time(:millisecond)
      end_memory = :erlang.memory(:total)

      # Stop memory monitoring
      send(memory_monitor, :stop)

      memory_samples =
        receive do
          {:memory_data, samples} -> samples
        after
          5000 -> []
        end

      {result,
       %{
         duration: end_time - start_time,
         start_memory: start_memory,
         end_memory: end_memory,
         peak_memory:
           Enum.max([end_memory | Enum.map(memory_samples, & &1.memory)], fn -> end_memory end),
         memory_samples: memory_samples
       }}
    rescue
      error ->
        send(memory_monitor, :stop)
        {:error, error}
    end
  end

  # Private helper for memory monitoring loop
  @spec monitor_memory_loop(term(), term()) :: term()
  defp monitor_memory_loop(parent, samples) do
    receive do
      :stop ->
        send(parent, {:memory_data, Enum.reverse(samples)})
    after
      100 ->
        timestamp = System.monotonic_time(:millisecond)
        memory = :erlang.memory(:total)
        sample = %{timestamp: timestamp, memory: memory}
        monitor_memory_loop(parent, [sample | samples])
    end
  end

  @doc """
  Perform root cause analysis on compilation warnings.

  Returns analysis results with recommendations.
  """
  @spec perform_rca_on_warnings(any()) :: any()
  def perform_rca_on_warnings(warnings) do
    stats = generate_warning_stats(warnings)

    # Identify patterns and root causes
    root_causes = analyze_root_causes(warnings)
    recommendations = generate_recommendations(root_causes, stats)

    %{
      summary: stats,
      root_causes: root_causes,
      recommendations: recommendations,
      severity: assess_severity(stats)
    }
  end

  # Private helpers for RCA
  @spec analyze_root_causes(term()) :: term()
  defp analyze_root_causes(warnings) do
    warnings
    |> Enum.group_by(&(&1[:category] || :uncategorized))
    |> Enum.map(fn {category, warning_list} ->
      common_patterns = extract_common_patterns(warning_list, nil)

      {category,
       %{
         count: length(warning_list),
         common_patterns: common_patterns,
         affected_files: warning_list |> Enum.map(& &1[:file]) |> Enum.uniq()
       }}
    end)
    |> Map.new()
  end

  defp extract_common_patterns(warnings, _req) do
    warnings
    |> Enum.map(& &1[:message])
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
  end

  @spec generate_recommendations(term(), term()) :: term()
  defp generate_recommendations(root_causes, _stats) do
    Enum.flat_map(root_causes, fn {category, analysis} ->
      case category do
        :atomic_warnings ->
          ["Add require_atomic? false to update actions with function-based changes"]

        :unused_code ->
          ["Remove unused variables and functions", "Review and clean up dead code paths"]

        :deprecation ->
          [
            "Update deprecated function calls to modern equivalents",
            "Check library documentation for migration guides"
          ]

        :typespec ->
          ["Add missing @spec annotations", "Fix invalid type specifications"]

        _ ->
          ["Review #{category} warnings in #{length(analysis.affected_files)} files"]
      end
    end)
  end

  @spec assess_severity(map()) :: term()
  defp assess_severity(%{total: total, by_category: by_category}) do
    cond do
      total == 0 -> :none
      Map.get(by_category, :atomic_warnings, 0) > 0 -> :critical
      total > 50 -> :high
      total > 20 -> :medium
      true -> :low
    end
  end

  @doc """
  Convert module name to file path.

  This function was extracted from multiple compilation modules to eliminate code duplication.
  Converts a module name (atom or string) to its corresponding file path in the lib directory.

  ## Examples

      iex> module_to_path(My App.SomeModule)
      "lib / my_app / some_module.ex"

      iex> module_to_path("My App.SomeModule")
      "lib / my_app / some_module.ex"
  """
  @spec module_to_path(any()) :: any()
  def module_to_path(module) when is_atom(module) do
    module
    |> to_string()
    |> module_to_path()
  end

  @spec module_to_path(any()) :: any()
  def module_to_path(module) when is_binary(module) do
    module
    |> String.split(".")
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> then(&"lib/#{&1}.ex")
  end
end
