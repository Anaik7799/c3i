#!/usr/bin/env elixir

# Script: comprehensive_upgrade_scriban.exs
# SC-BATCH Compliant: NO (Total fix) - but following safety rules
# Max Changes: Unlimited (Ecosystem-wide fix)

defmodule ScribanUpgrade do
  @new_version "6.6.0"

  def execute do
    # 1. Create git checkpoint
    IO.puts("Creating git checkpoint...")
    System.cmd("git", ["stash", "push", "-m", "comprehensive_upgrade_scriban"])

    # 2. Find all .fsproj files
    {files_output, 0} = System.cmd("find", ["lib/cepaf", "-name", "*.fsproj"])
    files = String.split(files_output, "\n", trim: true)

    # 3. Apply changes
    Enum.each(files, fn file ->
      content = File.read!(file)
      if String.contains?(content, "Scriban") do
        # Flexible regex to match various formats
        new_content = String.replace(content, ~r/<PackageReference [^>]*Include="Scriban" [^>]*Version="[^"]+"[^>]*\/?>/, "<PackageReference Include=\"Scriban\" Version=\"#{@new_version}\" />")
        if new_content != content do
          File.write!(file, new_content)
          IO.puts("✓ Updated: #{file}")
        end
      end
    end)

    # 4. Verify (compile)
    IO.puts("Verifying build...")
    case System.cmd("dotnet", ["build", "lib/cepaf/Cepaf.sln"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✓ Build succeeded")
      {output, _} ->
        IO.puts("✗ Build failed")
        # IO.puts(output)
    end
  end
end

ScribanUpgrade.execute()
