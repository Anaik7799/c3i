#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule GeminiSymbiosisValidator do
  @doc "Validates the functional parity and symbiosis of the Gemini CLI integration"

  @claude_dir ".claude"
  @gemini_dir ".gemini"

  @sub_dirs ["rules", "agents", "skills", "commands", "plans", "worktrees"]

  def validate do
    IO.puts("==================================================================")
    IO.puts("GEMINI CLI SYMBIOSIS VALIDATOR")
    IO.puts("==================================================================\n")

    check_directory_structure()
    check_file_count_parity()
    check_json_validity()
    check_file_content_parity()

    IO.puts("\n==================================================================")
    IO.puts("VALIDATION COMPLETE")
    IO.puts("==================================================================")
  end

  defp check_directory_structure do
    IO.puts("1. Checking Directory Structure...")

    if File.dir?(@gemini_dir) do
      IO.puts("  [PASS] .gemini directory exists")
    else
      IO.puts("  [FAIL] .gemini directory missing")
    end

    Enum.each(@sub_dirs, fn dir ->
      path = Path.join(@gemini_dir, dir)
      if File.dir?(path) do
        IO.puts("  [PASS] #{path} directory exists")
      else
        IO.puts("  [WARN] #{path} directory missing (might be expected if empty)")
      end
    end)
  end

  defp check_file_count_parity do
    IO.puts("\n2. Checking File Count Parity...")

    Enum.each(@sub_dirs, fn dir ->
      claude_path = Path.join(@claude_dir, dir)
      gemini_path = Path.join(@gemini_dir, dir)

      claude_count = count_files(claude_path)
      gemini_count = count_files(gemini_path)

      if claude_count == gemini_count do
        IO.puts("  [PASS] #{dir}/ : #{claude_count} files in both")
      else
        IO.puts("  [FAIL] #{dir}/ : .claude has #{claude_count}, .gemini has #{gemini_count}")
      end
    end)
  end

  defp count_files(path) do
    if File.dir?(path) do
      path
      |> File.ls!()
      |> Enum.count(fn f -> not File.dir?(Path.join(path, f)) end)
    else
      0
    end
  end

  defp check_json_validity do
    IO.puts("\n3. Checking JSON Validity...")

    check_json_file(Path.join(@gemini_dir, "settings.json"))
    check_json_file(Path.join(@gemini_dir, "settings.local.json"))
  end

  defp check_json_file(file) do
    if File.exists?(file) do
      content = File.read!(file)
      case Jason.decode(content) do
        {:ok, _} -> IO.puts("  [PASS] #{file} is valid JSON")
        {:error, reason} -> IO.puts("  [FAIL] #{file} is invalid JSON: #{inspect(reason)}")
      end
    else
      IO.puts("  [WARN] #{file} does not exist")
    end
  end

  defp check_file_content_parity do
    IO.puts("\n4. Checking Content References in .gemini/...")

    # Just a sample check of rules to ensure they don't contain CLAUDE.md references
    # incorrectly. It's a heuristic.
    rules_dir = Path.join(@gemini_dir, "rules")
    if File.dir?(rules_dir) do
      files = File.ls!(rules_dir) |> Enum.filter(&String.ends_with?(&1, ".md"))
      
      # We check a few files for CLAUDE.md. There might be 0, which is perfect since we replaced it.
      claude_refs = Enum.reduce(files, 0, fn file, acc ->
        content = File.read!(Path.join(rules_dir, file))
        if String.contains?(content, "CLAUDE.md") do
          acc + 1
        else
          acc
        end
      end)

      gemini_refs = Enum.reduce(files, 0, fn file, acc ->
        content = File.read!(Path.join(rules_dir, file))
        if String.contains?(content, "GEMINI.md") do
          acc + 1
        else
          acc
        end
      end)

      if claude_refs == 0 do
        IO.puts("  [PASS] 0 files in .gemini/rules/ reference CLAUDE.md")
      else
        IO.puts("  [WARN] #{claude_refs} files in .gemini/rules/ still reference CLAUDE.md")
      end

      if gemini_refs > 0 do
        IO.puts("  [PASS] #{gemini_refs} files in .gemini/rules/ reference GEMINI.md")
      else
        IO.puts("  [WARN] No files in .gemini/rules/ reference GEMINI.md")
      end
    end
  end
end

GeminiSymbiosisValidator.validate()
