#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FunctionalDevContainer do
  @moduledoc """
  Master script to create a fully functional NixOS development container
  with all fixes applied:
  - Elixir 1.19.2 with Erlang/OTP 27
  - UTF-8 locale support via glibcLocales
  - Multi-path SSL certificate strategy
  - PAM-free user switching with setpriv
  - PHICS v2.1 hot-reloading support
  """

  def main(args) do
    IO.puts("🚀 Creating Fully Functional NixOS Development Container")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    case args do
      ["--build"] -> build_container()
      ["--load"] -> load_container()
      ["--start"] -> start_container()
      ["--verify"] -> verify_container()
      ["--all"] -> run_all_steps()
      ["--help"] -> show_help()
      _ -> show_help()
    end
  end

  defp run_all_steps do
    IO.puts("\n📋 Running all steps to create functional container...")

    with :ok <- build_container(),
         :ok <- load_container(),
         :ok <- start_container(),
         :ok <- verify_container() do
      IO.puts("\n✅ All steps completed successfully!")
      IO.puts("\n🎯 Container is ready for development:")
      IO.puts("   - Elixir 1.19.2 with Erlang/OTP 27")
      IO.puts("   - UTF-8 locale fully supported")
      IO.puts("   - SSL/TLS certificates working")
      IO.puts("   - PHICS hot-reloading enabled")
      IO.puts("")
      IO.puts("📝 Usage:")
      IO.puts("   podman exec intelitor-dev bash -c \"source /etc/profile.d/intelitor.sh && cd /workspace && mix compile\"")
      :ok
    else
      {:error, step, reason} ->
        IO.puts("\n❌ Failed at step: #{step}")
        IO.puts("   Reason: #{reason}")
        {:error, step}
    end
  end

  defp build_container do
    IO.puts("\n1️⃣ Building NixOS container with all fixes...")

    container_dir = Path.expand("../../containers", __DIR__)
    nix_file = Path.join(container_dir, "sopv51-dev-comprehensive.nix")

    unless File.exists?(nix_file) do
      return_error("build", "Container definition not found: #{nix_file}")
    end

    # Verify the container definition has all required fixes
    content = File.read!(nix_file)

    checks = [
      {"Elixir 1.19", ~r/elixir_1_19/},
      {"glibcLocales", ~r/pkgs\.glibcLocales/},
      {"LOCALE_ARCHIVE", ~r/LOCALE_ARCHIVE.*glibcLocales/},
      {"SSL certificates", ~r/cacert.*ca-bundle\.crt/},
      {"setpriv", ~r/setpriv/}
    ]

    missing = Enum.filter(checks, fn {name, pattern} ->
      not (content =~ pattern)
    end)

    unless Enum.empty?(missing) do
      missing_names = Enum.map(missing, fn {name, _} -> name end)
      return_error("build", "Container definition missing fixes: #{Enum.join(missing_names, ", ")}")
    end

    IO.puts("   ✓ Container definition verified with all fixes")

    # Build the container
    IO.puts("   Building container (this may take a few minutes)...")

    case System.cmd("nix-build", [nix_file], cd: container_dir, stderr_to_stdout: true) do
      {output, 0} ->
        # Extract the output path
        image_path = output
          |> String.split("\n")
          |> List.last()
          |> String.trim()

        if File.exists?(image_path) do
          IO.puts("   ✅ Container built successfully")
          IO.puts("   📦 Image: #{image_path}")

          # Save the image path for later steps
          File.write!("/tmp/intelitor-container-path.txt", image_path)
          :ok
        else
          return_error("build", "Image path not found: #{image_path}")
        end

      {output, exit_code} ->
        IO.puts("   Build output:")
        IO.puts(output)
        return_error("build", "nix-build failed with exit code #{exit_code}")
    end
  end

  defp load_container do
    IO.puts("\n2️⃣ Loading container image into Podman...")

    image_path = case File.read("/tmp/intelitor-container-path.txt") do
      {:ok, path} -> String.trim(path)
      {:error, _} ->
        return_error("load", "Container image path not found. Run --build first.")
    end

    unless File.exists?(image_path) do
      return_error("load", "Container image not found: #{image_path}")
    end

    IO.puts("   Loading from: #{image_path}")

    case System.cmd("podman", ["load"], stdin: File.read!(image_path), stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("   ✅ Container image loaded")
        IO.puts(String.trim(output))
        :ok

      {output, exit_code} ->
        IO.puts(output)
        return_error("load", "podman load failed with exit code #{exit_code}")
    end
  end

  defp start_container do
    IO.puts("\n3️⃣ Starting development container...")

    # Stop and remove existing container if it exists
    System.cmd("podman", ["stop", "intelitor-dev"], stderr_to_stdout: true)
    System.cmd("podman", ["rm", "intelitor-dev"], stderr_to_stdout: true)

    workspace = Path.expand("../..", __DIR__)

    IO.puts("   Workspace: #{workspace}")
    IO.puts("   Container: intelitor-dev")
    IO.puts("   Ports: 4000 (Phoenix), 4001 (LiveReload)")

    args = [
      "run", "-d",
      "--name", "intelitor-dev",
      "-v", "#{workspace}:/workspace:z",
      "-p", "4000:4000",
      "-p", "4001:4001",
      "localhost/intelitor-dev:nixos-25.05-unknown"
    ]

    case System.cmd("podman", args, stderr_to_stdout: true) do
      {output, 0} ->
        container_id = String.trim(output)
        IO.puts("   ✅ Container started")
        IO.puts("   🆔 Container ID: #{String.slice(container_id, 0..11)}")

        # Wait for container to be ready
        IO.puts("   Waiting for container to be ready...")
        Process.sleep(2000)
        :ok

      {output, exit_code} ->
        IO.puts(output)
        return_error("start", "podman run failed with exit code #{exit_code}")
    end
  end

  defp verify_container do
    IO.puts("\n4️⃣ Verifying container functionality...")

    tests = [
      {"Container running", ["ps", "-q", "-f", "name=intelitor-dev"]},
      {"Elixir version", ["exec", "intelitor-dev", "bash", "-c",
        "source /etc/profile.d/intelitor.sh && elixir --version"]},
      {"Mix accessible", ["exec", "intelitor-dev", "bash", "-c",
        "source /etc/profile.d/intelitor.sh && cd /workspace && ls -la mix.exs"]},
      {"Locale support", ["exec", "intelitor-dev", "bash", "-c",
        "source /etc/profile.d/intelitor.sh && echo $LOCALE_ARCHIVE"]},
      {"SSL certificates", ["exec", "intelitor-dev", "bash", "-c",
        "ls -la /etc/ssl/certs/ca-bundle.crt"]}
    ]

    results = Enum.map(tests, fn {test_name, args} ->
      case System.cmd("podman", args, stderr_to_stdout: true) do
        {output, 0} ->
          IO.puts("   ✅ #{test_name}")
          if test_name == "Elixir version" do
            version_line = output
              |> String.split("\n")
              |> Enum.find(&(&1 =~ ~r/Elixir \d+\.\d+\.\d+/))
            if version_line, do: IO.puts("      #{String.trim(version_line)}")
          end
          {:ok, test_name}

        {output, _exit_code} ->
          IO.puts("   ❌ #{test_name}")
          IO.puts("      #{String.trim(output)}")
          {:error, test_name}
      end
    end)

    failed = Enum.filter(results, fn
      {:error, _} -> true
      _ -> false
    end)

    if Enum.empty?(failed) do
      IO.puts("\n   ✅ All verification tests passed")
      :ok
    else
      failed_names = Enum.map(failed, fn {:error, name} -> name end)
      return_error("verify", "Tests failed: #{Enum.join(failed_names, ", ")}")
    end
  end

  defp show_help do
    IO.puts("""

    Usage: elixir create_functional_dev_container.exs [OPTION]

    Create a fully functional NixOS development container with all fixes applied.

    Options:
      --build     Build the NixOS container from source
      --load      Load the built container image into Podman
      --start     Start the development container
      --verify    Verify container functionality
      --all       Run all steps (build, load, start, verify)
      --help      Show this help message

    Included Fixes:
      ✓ Elixir 1.19.2 with Erlang/OTP 27
      ✓ UTF-8 locale support (glibcLocales + LOCALE_ARCHIVE)
      ✓ Multi-path SSL certificate strategy
      ✓ PAM-free user switching (setpriv)
      ✓ PHICS v2.1 hot-reloading support

    Examples:
      # Create complete functional container
      elixir create_functional_dev_container.exs --all

      # Build only
      elixir create_functional_dev_container.exs --build

      # Verify existing container
      elixir create_functional_dev_container.exs --verify

    After creation, use the container:
      podman exec intelitor-dev bash -c "source /etc/profile.d/intelitor.sh && cd /workspace && mix compile"
    """)
  end

  defp return_error(step, reason) do
    {:error, step, reason}
  end
end

FunctionalDevContainer.main(System.argv())
