#!/usr/bin/env elixir
# Parallel Build Agent: Cybernetic AEE Build Orchestrator
# Version: 1.0.0
# Framework: SOPv5.11 + TPS + OODA + Max Parallelization

Code.require_file("lib/indrajaal/deployment/config.ex")
alias Indrajaal.Deployment.Config

defmodule ParallelBuildAgent do
  def run do
    IO.puts("🤖 Cybernetic Build Agent Activation...")
    IO.puts("🚀 Parallelizing build loops for maximum throughput...")

    containers = Config.containers()
    
    # Observe: Filter for containers that have nix files
    build_targets = Enum.filter(containers, & &1[:nix_file])

    # Decide & Act: Execute builds in parallel
    results = 
      build_targets
      |> Task.async_stream(fn target -> 
        build_service(target)
      end, max_concurrency: 4, timeout: :infinity)
      |> Enum.to_list()

    # Final Audit
    IO.puts("\n📊 BUILD AUDIT REPORT:")
    Enum.each(results, fn 
      {:ok, {:ok, name}} -> IO.puts("  ✅ #{name}: SUCCESS")
      {:ok, {:error, name, error}} -> IO.puts("  ❌ #{name}: FAILED\n#{error}")
      other -> IO.puts("  ⚠️ UNEXPECTED RESULT: #{inspect(other)}")
    end)

    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      IO.puts("\n✨ ALL TARGETS CERTIFIED.")
    else
      IO.puts("\n🛑 CRITICAL BUILD FAILURE. Inspect logs.")
      System.halt(1)
    end
  end

  defp build_service(target) do
    name = target.service_name
    nix_file = Path.join("containers", target.nix_file)
    image_tag = "localhost/#{target.image_name}:#{target.image_tag}"

    IO.puts("🏗️ Building #{name} -> #{image_tag}...")

    env = [{"NIXPKGS_ALLOW_UNFREE", "1"}]

    case System.cmd("nix-build", [nix_file, "--no-out-link"], stderr_to_stdout: true, env: env) do
      {output, 0} ->
        # Nix output can contain build logs. The last line is usually the path.
        path = 
          output
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&String.starts_with?(&1, "/nix/store/"))
          |> List.last()

        if path && File.exists?(path) do
          IO.puts("📦 Importing #{name} image from #{path}...")
          case System.cmd("podman", ["load", "-i", path], stderr_to_stdout: true) do
            {_, 0} -> 
              {:ok, name}
            {err, _} -> 
              {:error, name, "Podman load failed: #{err}"}
          end
        else
          {:error, name, "Could not find build output path in: \n#{output}"}
        end
      {error, _} ->
        {:error, name, "Nix build failed: #{error}"}
    end
  end
end

ParallelBuildAgent.run()
