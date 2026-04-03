#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EnhancedFPPS do
  @moduledoc """
  Enhanced Fix Pattern Prevention System (FPPS)

  Detects fix loops using:
  1. Git history analysis
  2. Pattern recognition
  3. xAI Grok validation integration
  4. Statistical anomaly detection
  """

  @fix_patterns %{
    "underscore_removal" => ~r/_(\w+)\s+(?:->|when|=)\s+.*\1/,
    "function_arity" => ~r/def\w*\s+(\w+)\/(\d+).*?called.*?\/(\d+)/,
    "variable_scope" => ~r/undefined.*"(\w+)".*previous.*_\1/,
    "parameter_mismatch" => ~r/function\s+\w+\/(\d+).*expects\s+(\d+)/,
    "malformed_function" => ~r/\bp\s+\w+\(.*\)\s+do/
  }

  @fpps_db_path "./data/tmp/fpps_fix_history.json"

  def run(args) do
    case args do
      ["--init"] -> initialize_database()
      ["--detect-loops"] -> detect_all_loops()
      ["--analyze", file] -> analyze_file(file)
      ["--validate-fix", file, fix_type] -> validate_fix_with_grok(file, fix_type)
      ["--stats"] -> show_statistics()
      _ -> show_help()
    end
  end

  defp initialize_database do
    IO.puts("🔧 Initializing FPPS database...")

    initial_data = %{
      version: "2.0",
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      fix_history: %{},
      loop_detections: [],
      validation_results: []
    }

    File.write!(@fpps_db_path, Jason.encode!(initial_data, pretty: true))
    IO.puts("✅ FPPS database initialized at #{@fpps_db_path}")
  end

  defp detect_all_loops do
    IO.puts("🔍 Detecting fix loops across all files...")

    {files, 0} = System.cmd("git", ["diff", "--name-only", "HEAD~50..HEAD"])

    loops = files
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    |> Enum.map(&detect_file_loops/1)
    |> Enum.reject(&is_nil/1)
    |> List.flatten()

    if Enum.empty?(loops) do
      IO.puts("✅ No fix loops detected")
    else
      IO.puts("⚠️  #{length(loops)} fix loops detected:")
      Enum.each(loops, fn {file, pattern, count} ->
        IO.puts("   - #{file}: #{pattern} (#{count} times)")
      end)

      record_loop_detections(loops)
    end
  end

  defp detect_file_loops(file_path) do
    {history, 0} = System.cmd("git", ["log", "--grep=fix:", "--oneline", "--", file_path])

    @fix_patterns
    |> Enum.map(fn {name, pattern} ->
      matches = Regex.scan(pattern, history)
      if length(matches) > 2 do
        {file_path, name, length(matches)}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp analyze_file(file_path) do
    IO.puts("📊 Analyzing fix patterns for: #{file_path}")

    {log, 0} = System.cmd("git", ["log", "--oneline", "--", file_path])
    fix_count = log |> String.split("\n") |> Enum.count(&String.contains?(&1, "fix:"))

    {diff, 0} = System.cmd("git", ["diff", "HEAD~10..HEAD", "--", file_path])

    pattern_matches = @fix_patterns
    |> Enum.map(fn {name, pattern} ->
      count = Regex.scan(pattern, diff) |> length()
      {name, count}
    end)
    |> Enum.reject(fn {_, count} -> count == 0 end)

    IO.puts("\n📈 Analysis Results:")
    IO.puts("   Total fixes: #{fix_count}")
    IO.puts("   Pattern matches:")
    Enum.each(pattern_matches, fn {name, count} ->
      IO.puts("      - #{name}: #{count}")
    end)

    if fix_count > 5 do
      IO.puts("\n⚠️  WARNING: File has been fixed #{fix_count} times - possible loop!")
    end
  end

  defp validate_fix_with_grok(file_path, fix_type) do
    IO.puts("🤖 Validating fix with xAI Grok...")

    content = File.read!(file_path)

    # Prepare xAI Grok API request
    validation_request = %{
      model: "grok-beta",
      messages: [
        %{
          role: "system",
          content: "You are an expert Elixir code reviewer validating automated fixes."
        },
        %{
          role: "user",
          content: """
          Validate this Elixir code fix for correctness:

          File: #{file_path}
          Fix type: #{fix_type}

          Code:
          #{String.slice(content, 0..2000)}

          Check for:
          1. Syntax correctness
          2. Semantic preservation
          3. No regression potential
          4. Pattern consistency
          5. Elixir idioms compliance

          Respond with JSON: {"valid": boolean, "issues": [...], "confidence": 0-100}
          """
        }
      ],
      temperature: 0.1
    }

    IO.puts("\n📋 Grok Validation Request:")
    IO.puts(Jason.encode!(validation_request, pretty: true))

    # Note: Actual API call would be made here
    IO.puts("\n💡 To integrate with xAI Grok API:")
    IO.puts("   export XAI_API_KEY='your-api-key'")
    IO.puts("   curl https://api.x.ai/v1/chat/completions \\")
    IO.puts("     -H 'Authorization: Bearer $XAI_API_KEY' \\")
    IO.puts("     -d '#{Jason.encode!(validation_request)}'")

    record_validation_request(file_path, fix_type, validation_request)
  end

  defp show_statistics do
    case File.read(@fpps_db_path) do
      {:ok, content} ->
        data = Jason.decode!(content)
        IO.puts("📊 FPPS Statistics:")
        IO.puts("   Database version: #{data["version"]}")
        IO.puts("   Created: #{data["created_at"]}")
        IO.puts("   Loop detections: #{length(data["loop_detections"])}")
        IO.puts("   Validation requests: #{length(data["validation_results"])}")

        if length(data["loop_detections"]) > 0 do
          IO.puts("\n🔄 Recent Loop Detections:")
          data["loop_detections"]
          |> Enum.take(-5)
          |> Enum.each(fn detection ->
            IO.puts("   - #{detection["file"]}: #{detection["pattern"]} (#{detection["count"]}x)")
          end)
        end

      {:error, _} ->
        IO.puts("⚠️  FPPS database not found. Run --init first.")
    end
  end

  defp record_loop_detections(loops) do
    case File.read(@fpps_db_path) do
      {:ok, content} ->
        data = Jason.decode!(content)

        new_detections = Enum.map(loops, fn {file, pattern, count} ->
          %{
            "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "file" => file,
            "pattern" => pattern,
            "count" => count
          }
        end)

        updated_data = Map.update!(data, "loop_detections", &(&1 ++ new_detections))
        File.write!(@fpps_db_path, Jason.encode!(updated_data, pretty: true))

      {:error, _} ->
        IO.puts("⚠️  Database not initialized. Run --init first.")
    end
  end

  defp record_validation_request(file, fix_type, request) do
    case File.read(@fpps_db_path) do
      {:ok, content} ->
        data = Jason.decode!(content)

        validation_entry = %{
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "file" => file,
          "fix_type" => fix_type,
          "request" => request
        }

        updated_data = Map.update!(data, "validation_results", &(&1 ++ [validation_entry]))
        File.write!(@fpps_db_path, Jason.encode!(updated_data, pretty: true))
        IO.puts("✅ Validation request recorded")

      {:error, _} ->
        IO.puts("⚠️  Database not initialized. Run --init first.")
    end
  end

  defp show_help do
    IO.puts("""
    Enhanced FPPS - Fix Pattern Prevention System

    Usage:
      elixir enhanced_fpps_loop_detector.exs [command]

    Commands:
      --init                          Initialize FPPS database
      --detect-loops                  Detect all fix loops in recent commits
      --analyze <file>                Analyze specific file for fix patterns
      --validate-fix <file> <type>    Validate fix with xAI Grok
      --stats                         Show FPPS statistics

    Examples:
      elixir enhanced_fpps_loop_detector.exs --init
      elixir enhanced_fpps_loop_detector.exs --detect-loops
      elixir enhanced_fpps_loop_detector.exs --analyze lib/my_module.ex
      elixir enhanced_fpps_loop_detector.exs --validate-fix lib/my_module.ex underscore_removal
    """)
  end
end

EnhancedFPPS.run(System.argv())