#!/usr/bin/env elixir

defmodule ContextUnderscoreFixer do
  @moduledoc """
  Fixes double underscore parameter issues in context files.

  Changes __param to _param in function definitions where the parameter
  has a double underscore but is not actually used (placeholder functions).
  """

  def fix_file(file_path) do
    IO.puts("\n📝 Processing: #{Path.basename(file_path)}")

    content = File.read!(file_path)

    # Replace double underscore with single underscore in function parameters
    # This matches patterns like: defp function_name(__param1, __param2)
    fixed_content = content
    |> String.replace(~r/defp\s+(\w+)\(([^)]*__[^)]*)\)/, fn match ->
      String.replace(match, ~r/__(\w+)/, "_\\1")
    end)
    |> String.replace(~r/def\s+(\w+)\(([^)]*__[^)]*)\)/, fn match ->
      String.replace(match, ~r/__(\w+)/, "_\\1")
    end)

    if content != fixed_content do
      # Create backup
      backup_path = file_path <> ".backup"
      File.write!(backup_path, content)

      # Write fixed content
      File.write!(file_path, fixed_content)

      IO.puts("✅ Fixed #{Path.basename(file_path)}")
      IO.puts("   Backup created: #{backup_path}")
      {:ok, :fixed}
    else
      IO.puts("ℹ️  No changes needed for #{Path.basename(file_path)}")
      {:ok, :no_changes}
    end
  end

  def fix_all_contexts do
    context_files = Path.wildcard("lib/indrajaal/*_context.ex")

    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("Context File Underscore Fixer")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("\nFound #{length(context_files)} context files to process\n")

    results = Enum.map(context_files, &fix_file/1)

    fixed_count = Enum.count(results, fn {_, result} -> result == :fixed end)
    unchanged_count = Enum.count(results, fn {_, result} -> result == :no_changes end)

    IO.puts("\n" <> String.duplicate("=", 72))
    IO.puts("Summary:")
    IO.puts("  Total files: #{length(context_files)}")
    IO.puts("  Fixed: #{fixed_count}")
    IO.puts("  Unchanged: #{unchanged_count}")
    IO.puts(String.duplicate("=", 72))
  end
end

# Run the fixer
ContextUnderscoreFixer.fix_all_contexts()
