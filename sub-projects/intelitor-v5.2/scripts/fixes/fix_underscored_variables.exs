#!/usr/bin/env elixir

# Automated Underscored Variable Fixer
# Fixes warnings about underscored variables being used

defmodule UnderscoredVariableFixer do
  @moduledoc """
  Systematically fixes underscored variables that are actually used.

  Pattern: "the underscored variable \"_var\" is used after being set"
  Fix: Remove the leading underscore from the variable name
  """

  def fix_file(file_path) do
    IO.puts("\n=== Processing: #{file_path} ===")

    content = File.read!(file_path)

    # Common underscore patterns that need fixing
    patterns_to_fix = [
      {"_attrs", "attrs"},
      {"_item", "item"},
      {"_user", "user"},
      {"_tenant_id", "tenant_id"},
      {"_context", "context"},
      {"_params", "params"},
      {"_opts", "opts"},
      {"_data", "data"},
      {"_req", "req"},
      {"_resource", "resource"},
      {"_action", "action"},
      {"__attrs", "attrs"},
      {"__item", "item"},
      {"__user", "user"},
      {"__tenant_id", "tenant_id"},
      {"__context", "context"},
      {"__params", "params"},
      {"__opts", "opts"},
      {"__data", "data"},
      {"__req", "req"},
      {"__resource", "resource"},
      {"__action", "action"}
    ]

    # Apply fixes
    fixed_content = Enum.reduce(patterns_to_fix, content, fn {old, new}, acc ->
      # Only fix in function parameter lists and usage within function bodies
      # Be careful not to fix legitimate uses of _ prefix for truly unused vars
      acc
      |> String.replace(~r/defp\s+\w+\(([^)]*#{Regex.escape(old)})/, fn match ->
        String.replace(match, old, new)
      end)
      |> String.replace(~r/def\s+\w+\(([^)]*#{Regex.escape(old)})/, fn match ->
        String.replace(match, old, new)
      end)
    end)

    if content != fixed_content do
      File.write!(file_path, fixed_content)
      IO.puts("✅ Fixed underscored variables in #{file_path}")
      {:ok, :fixed}
    else
      IO.puts("ℹ️  No changes needed in #{file_path}")
      {:ok, :no_changes}
    end
  end

  def fix_all_context_files do
    IO.puts("Starting automated underscore variable fixing...")

    # Get all context files that likely have these issues
    context_files = Path.wildcard("lib/indrajaal/*_context.ex")

    results = Enum.map(context_files, fn file ->
      fix_file(file)
    end)

    fixed_count = Enum.count(results, fn {_, result} -> result == :fixed end)

    IO.puts("\n=== Summary ===")
    IO.puts("Total files processed: #{length(context_files)}")
    IO.puts("Files fixed: #{fixed_count}")
    IO.puts("Files unchanged: #{length(context_files) - fixed_count}")
  end
end

# Run the fixer
UnderscoredVariableFixer.fix_all_context_files()
