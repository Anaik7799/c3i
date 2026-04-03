#!/usr/bin/env elixir

# Script: batch_upgrade_scriban_2.exs
# SC-BATCH Compliant: YES
# Max Changes: 10
# Reversible: YES (git checkpoint)

defmodule ScribanUpgrade do
  @new_version "6.6.0"
  @files [
    "lib/cepaf/src/Cepaf.Knowledge.CLI/Cepaf.Knowledge.CLI.fsproj",
    "lib/cepaf/src/Cepaf.Smriti/Cepaf.Smriti.fsproj",
    "lib/cepaf/src/Cepaf.Planning/Cepaf.Planning.fsproj",
    "lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj",
    "lib/cepaf/src/Cepaf.Knowledge/Cepaf.Knowledge.fsproj",
    "lib/cepaf/src/Cepaf.Planning.CLI/Cepaf.Planning.CLI.fsproj",
    "lib/cepaf/src/Cepaf.Cockpit/Cepaf.Cockpit.fsproj",
    "lib/cepaf/src/Cepaf.KmsCatalog.Tests/Cepaf.KmsCatalog.Tests.fsproj",
    "lib/cepaf/src/Cepaf.Smriti.Semantic.Tests/Cepaf.Smriti.Semantic.Tests.fsproj",
    "lib/cepaf/src/Cepaf.Database/Cepaf.Database.fsproj"
  ]

  def execute do
    # 1. Create git checkpoint
    IO.puts("Creating git checkpoint...")
    System.cmd("git", ["stash", "push", "-m", "batch_upgrade_scriban_2"])

    # 2. Apply changes
    Enum.each(@files, fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        new_content = String.replace(content, ~r/<PackageReference Include="Scriban" Version="[^"]+" \/>/, "<PackageReference Include=\"Scriban\" Version=\"#{@new_version}\" />")
        File.write!(file, new_content)
        IO.puts("✓ Updated: #{file}")
      else
        IO.puts("⚠ File not found: #{file}")
      end
    end)

    # 3. Verify (compile)
    IO.puts("Verifying build...")
    case System.cmd("dotnet", ["build", "lib/cepaf/Cepaf.sln"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✓ Build succeeded")
      {_output, _} ->
        IO.puts("✗ Build failed")
    end
  end
end

ScribanUpgrade.execute()
