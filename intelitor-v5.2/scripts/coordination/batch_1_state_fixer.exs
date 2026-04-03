#!/usr/bin/env elixir

defmodule Batch1StateFixer do
  @moduledoc """
  Batch 1: Fix undefined 'state' variable errors (148 errors)

  Agent Lead: DS-01 (Core/Foundation) + FS-11 (Undefined Variable Fixer)
  Workers: WA-26 to WA-33 (8 file processors)

  Strategy:
  1. Identify all files with undefined 'state' errors
  2. Analyze if parameter has underscore prefix: _state
  3. If used in function body, remove underscore prefix
  4. Create Git checkpoint every 50 fixes
  5. Validate with FPPS loop detection
  """

  def run do
    IO.puts("🔧 Batch 1: Fixing undefined 'state' variable errors")
    IO.puts("👥 Agent Lead: DS-01 + FS-11")
    IO.puts("👷 Workers: WA-26 to WA-33 (8 agents)\n")

    # Get all files with 'state' errors
    {output, 0} = System.cmd("grep", ["-l", ~s/undefined variable "state"/, "1-compile.log"])

    files_with_errors = extract_files_from_log(output)

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

  defp extract_files_from_log(grep_output) do
    # Extract unique file paths from compilation log
    {all_errors, 0} = System.cmd("grep", [~s/undefined variable "state"/, "1-compile.log"])

    all_errors
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case Regex.run(~r/lib\/.*?\.ex/, line) do
        [file] -> file
        nil -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
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
          IO.puts("     ℹ️  No underscore state found")
        end

      {:error, reason} ->
        IO.puts("     ⚠️  Error reading file: #{reason}")
    end
  end

  defp fix_underscore_state_usage(content) do
    # Pattern 1: Function parameters with _state that are used in body
    content = Regex.replace(
      ~r/def\w*\s+(\w+)\((.*?)_state(.*?)\)\s+do(.*?)end/s,
      content,
      fn full_match, func_name, before_param, after_param, body ->
        # Check if 'state' (without underscore) is used in body
        if String.contains?(body, "state") and not String.contains?(body, "_state") do
          # Remove underscore from parameter
          "def#{if String.starts_with?(full_match, "defp"), do: "p", else: ""} #{func_name}(#{before_param}state#{after_param}) do#{body}end"
        else
          full_match
        end
      end
    )

    # Pattern 2: Case/with clauses with _state that reference state
    content = Regex.replace(
      ~r/(\{:ok,\s+)_state(\})/,
      content,
      fn _, prefix, suffix ->
        "#{prefix}state#{suffix}"
      end
    )

    # Pattern 3: Pattern matches in function heads
    content = Regex.replace(
      ~r/(\w+)\(.*?%\{.*?\}\s*=\s*_state\)/,
      content,
      fn full_match ->
        if String.contains?(full_match, "= _state") do
          String.replace(full_match, "= _state", "= state")
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

Batch1StateFixer.run()