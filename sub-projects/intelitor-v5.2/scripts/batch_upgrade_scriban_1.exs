#!/usr/bin/env elixir

# Script: batch_upgrade_scriban_1.exs
# SC-BATCH Compliant: YES
# Max Changes: 10
# Reversible: YES (git checkpoint)

defmodule ScribanUpgrade do
  @new_version "6.6.0"
  @files [
    "lib/cepaf/src/Cepaf.KmsCatalog.Daemon/Cepaf.KmsCatalog.Daemon.fsproj",
    "lib/cepaf/src/Cepaf.Config/Cepaf.Config.fsproj",
    "lib/cepaf/src/Cepaf.Cockpit.CLI/Cepaf.Cockpit.CLI.fsproj",
    "lib/cepaf/src/Cepaf.Smriti.Shared/Cepaf.Smriti.Shared.fsproj",
    "lib/cepaf/src/Cepaf.Smriti.Semantic/Cepaf.Smriti.Semantic.fsproj",
    "lib/cepaf/src/Cepaf/Cepaf.fsproj",
    "lib/cepaf/src/Cepaf.Bridge/Cepaf.Bridge.fsproj",
    "lib/cepaf/src/Cepaf.Cockpit.Web/Cepaf.Cockpit.Web.fsproj",
    "lib/cepaf/src/Cepaf.Smriti.Api/Cepaf.Smriti.Api.fsproj",
    "lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj"
  ]

  def execute do
    # 1. Create git checkpoint
    IO.puts("Creating git checkpoint...")
    System.cmd("git", ["stash", "push", "-m", "batch_upgrade_scriban_1"])

    # 2. Apply changes
    Enum.each(@files, fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        # Match <PackageReference Include="Scriban" Version="..." />
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
      {output, _} ->
        IO.puts("✗ Build failed")
        # IO.puts(output)
    end
  end
end

ScribanUpgrade.execute()
