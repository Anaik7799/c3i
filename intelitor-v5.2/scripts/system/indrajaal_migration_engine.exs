#!/usr/bin/env elixir

defmodule Indrajaal.MigrationEngine do
  @moduledoc """
  The Great Renaming Engine: Indrajaal -> Indrajaal.
  This script performs a comprehensive, safe, and logged migration of the entire codebase.
  """

  @old_name "Indrajaal"
  @new_name "Indrajaal"
  @old_app :indrajaal
  @new_app :indrajaal
  @old_dir "indrajaal"
  @new_dir "indrajaal"

  def run do
    IO.puts("\n🌀 INDRAJAAL MIGRATION ENGINE INITIATED 🌀")
    IO.puts("===========================================")

    # 1. File Content Replacement
    IO.puts("\n[Phase 1] Replacing text content in files...")
    replace_content_in_files()

    # 2. File Renaming
    IO.puts("\n[Phase 2] Renaming files...")
    rename_files()

    # 3. Directory Renaming
    IO.puts("\n[Phase 3] Renaming directories...")
    rename_directories()

    IO.puts("\n✅ MIGRATION COMPLETE. SYSTEM IS NOW INDRAJAAL.")
  end

  defp replace_content_in_files do
    # Targeted list to avoid binary files or huge git history
    files = Path.wildcard("{lib,test,config,scripts,rel}/**/*.{ex,exs,heex,eex,lock,sh,md,json,yaml,yml,nix}") ++ ["mix.exs", "README.md", "CLAUDE.md", "GEMINI.md"]

    Enum.each(files, fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        new_content = content
          |> String.replace(@old_name, @new_name)
          |> String.replace(":#{@old_app}", ":#{@new_app}")
          |> String.replace("otp_app: :#{@old_app}", "otp_app: :#{@new_app}")
          |> String.replace("indrajaal_", "indrajaal_")
          |> String.replace("indrajaal-", "indrajaal-")

        if content != new_content do
          File.write!(file, new_content)
          IO.puts("  📝 Updated: #{file}")
        end
      end
    end)
  end

  defp rename_files do
    files = Path.wildcard("**/*indrajaal*")
    # Sort by length descending to rename deeper files before their parent dirs change
    |> Enum.sort(&(String.length(&1) >= String.length(&2)))

    Enum.each(files, fn path ->
      if File.exists?(path) and not File.dir?(path) do
        new_path = String.replace(path, "indrajaal", "indrajaal")
        if path != new_path do
          File.rename!(path, new_path)
          IO.puts("  📄 Renamed File: #{path} -> #{new_path}")
        end
      end
    end)
  end

  defp rename_directories do
    # Rename specific top-level directories first
    dirs = [
      "lib/indrajaal",
      "lib/indrajaal_web",
      "test/indrajaal",
      "test/indrajaal_web"
    ]

    Enum.each(dirs, fn dir ->
      if File.dir?(dir) do
        new_dir = String.replace(dir, "indrajaal", "indrajaal")
        case File.rename(dir, new_dir) do
          :ok -> IO.puts("  wd Renamed Directory: #{dir} -> #{new_dir}")
          {:error, reason} -> IO.puts("  ❌ Failed to rename #{dir}: #{inspect(reason)}")
        end
      end
    end)
  end
end

Indrajaal.MigrationEngine.run()
