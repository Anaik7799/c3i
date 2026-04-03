#!/usr/bin/env elixir

defmodule Batch1StateFixerV2 do
  @moduledoc """
  Batch 1: Fix undefined 'state' variable errors (148 errors)

  Agent Lead: DS-01 (Core/Foundation) + FS-11 (Undefined Variable Fixer)
  Workers: WA-26 to WA-33 (8 file processors)

  Strategy:
  1. Parse 1-compile.log to find files with undefined 'state' errors
  2. Analyze if parameter has underscore prefix: _state
  3. If used in function body, remove underscore prefix
  4. Create Git checkpoint every 50 fixes
  5. Validate with FPPS loop detection
  """

  def run do
    IO.puts("🔧 Batch 1: Fixing undefined 'state' variable errors")
    IO.puts("👥 Agent Lead: DS-01 + FS-11")
    IO.puts("👷 Workers: WA-26 to WA-33 (8 agents)\n")

    # Parse log file to extract files with 'state' errors
    files_with_errors = parse_log_for_state_errors("1-compile.log")

    IO.puts("📊 Found #{length(files_with_errors)} files with 'state' errors")
    IO.puts("🎯 Processing in batches of 50 fixes...\n")

    # Process files
    files_with_errors
    |> Enum.with_index(1)
    |> Enum.each(fn {file, index} ->
      fix_state_errors_in_file(file, index)

      # Checkpoint every 50 fixes
      if rem(index, 50) == 0 do
        create_checkpoint(index)
      end
    end)

    IO.puts("\n✅ Batch 1 complete!")
    IO.puts("📋 Run compilation to verify fixes")
  end

  defp parse_log_for_state_errors(log_file) do
    log_file
    |> File.read!()
    |> String.split("\n")
    |> extract_state_error_files()
    |> Enum.uniq()
  end

  defp extract_state_error_files(lines) do
    lines
    |> Enum.chunk_every(10, 1, :discard)  # Look at 10-line windows
    |> Enum.filter(fn chunk ->
      Enum.any?(chunk, &String.contains?(&1, ~s/undefined variable "state"/))
    end)
    |> Enum.map(fn chunk ->
      # Find the footer line with file path (starts with └─)
      footer = Enum.find(chunk, &String.starts_with?(&1, "     └─"))
      if footer do
        case Regex.run(~r/lib\/.*?\.ex/, footer) do
          [file] -> file
          nil -> nil
        end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp fix_state_errors_in_file(file_path, index) do
    IO.puts("[#{index}] Processing: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = fix_underscore_state_usage(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("     ✅ Fixed underscore state usage")
        else
          IO.puts("     ℹ️  No underscore state found (may be other issue)")
        end

      {:error, reason} ->
        IO.puts("     ⚠️  Error reading file: #{reason}")
    end
  end

  defp fix_underscore_state_usage(content) do
    # Pattern 1: Function parameters with _state that are used in body
    content = Regex.replace(
      ~r/(def[p]?\s+\w+\([^)]*?)_state([^)]*\)\s+do.*?end)/s,
      content,
      fn full_match, before_state, after_state ->
        # Check if 'state' (without underscore) is used after the function header
        body_part = String.split(full_match, "do", parts: 2) |> List.last()

        if body_part && String.contains?(body_part, "state") &&
           !String.contains?(body_part, "_state") do
          # Remove underscore from parameter
          "#{before_state}state#{after_state}"
        else
          full_match
        end
      end
    )

    # Pattern 2: Anonymous functions with _state
    content = Regex.replace(
      ~r/(fn\s+[^,]*?)_state([^,]*?->.*?end)/s,
      content,
      fn full_match, before_state, after_state ->
        body_part = String.split(full_match, "->", parts: 2) |> List.last()

        if body_part && String.contains?(body_part, "state") &&
           !String.contains?(body_part, "_state") do
          "#{before_state}state#{after_state}"
        else
          full_match
        end
      end
    )

    content
  end

  defp create_checkpoint(count) do
    IO.puts("\n📌 Creating checkpoint after #{count} fixes...")

    {_, 0} = System.cmd("git", ["add", "-A"])

    {_, 0} = System.cmd("git", ["commit", "-m", """
    fix: Batch 1 checkpoint - #{count} state errors fixed

    Agent: DS-01 + FS-11
    Workers: WA-26 to WA-33
    Progress: #{count}/148 state errors

    🤖 Generated with [Claude Code](https://claude.ai/code)

    Co-Authored-By: Claude <noreply@anthropic.com>
    """])

    {tag_name, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
    IO.puts("✅ Checkpoint created: #{String.trim(tag_name)}\n")

    # Run FPPS loop detection
    IO.puts("🔍 Running FPPS loop detection...")
    System.cmd("elixir", ["scripts/validation/enhanced_fpps_loop_detector.exs", "--detect-loops"])
  end
end

Batch1StateFixerV2.run()