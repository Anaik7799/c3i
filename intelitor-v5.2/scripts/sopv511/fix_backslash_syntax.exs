#!/usr/bin/env elixir

defmodule BackslashSyntaxFixer do
  def main do
    IO.puts("🔧 Fixing backslash syntax errors in alarms/api.ex")

    file_path = "lib/indrajaal/alarms/api.ex"

    case File.read(file_path) do
      {:ok, content} ->
        # Fix the broken backslash syntax
        fixed_content = String.replace(content, " \\ []", " \\\\ []")

        case File.write(file_path, fixed_content) do
          :ok ->
            IO.puts("✅ Successfully fixed backslash syntax errors")
          {:error, reason} ->
            IO.puts("❌ Failed to write file: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to read file: #{reason}")
    end
  end
end

BackslashSyntaxFixer.main()