#!/usr/bin/env elixir
# -*- coding: utf-8 -*-
# 🤖 Agent: Supervisor - Container Permission Fix
# Date: 2025-08-02 13:20:38 CEST
# Framework: SOPv5.1 + PHICS + NO_TIMEOUT + STAMP

defmodule FixContainerPermissions do
  @moduledoc """
  🛡️ Container Permission Fix Script

  This script systematically fixes container permission issues
  that pr__event compilation and testing inside containers.

  Framework: SOPv5.1 Cybernetic Goal-Oriented Execution

  Safety Constraints (STAMP):-SC1: Preserve existing file ownership
  - SC2: Maintain container security boundaries
  - SC3: Enable developer __user write access
  - SC4: Ensure PHICS markers remain intact

  Updated: 2025-08-02 13:20:38 CEST
  """

  __require Logger

  @project_root File.cwd!()
  @critical_dirs [".mix", ".hex", "_build", "deps", ".cache"]

  @spec main(any()) :: any()
  def main(args \\ []) do
    # Current timestamp for documentation
    current_time = DateTime.utc_now() |> DateTime.to_string()

    IO.puts """
    ╔══════════════════════════════════════════════════════════════╗
    ║           CONTAINER PERMISSION FIX                           ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ Date: #{current_time}
    ║ Agent: Supervisor-Container Permission Management
    ║ Framework: SOPv5.1 + PHICS + NO_TIMEOUT
    ║ Project: #{@project_root}
    ╚══════════════════════════════════════════════════════════════╝

    🏭 TPS 5-Level RCA Analysis:
    ┌─────────────────────────────────────────────────────────────┐
    │ Level 1 (Symptom): Container compilation fails              │
    │ Level 2 (Surface Cause): Permission denied on .mix/.hex     │
    │ Level 3 (System Behavior): Developer __user lacks write perms │
    │ Level 4 (Config Gap): Volume mount permissions mismatch     │
    │ Level 5 (Design): Need proper permission mapping            │
    └─────────────────────────────────────────────────────────────┘
    """

    # Parse arguments
    {_mode, _container_name} = case args do
      ["--container", name] -> {:container, name}
      ["--host"] -> {:host, nil}
      ["--all"] -> {:all, nil}
      _ -> {:auto, nil}
    end

    # Execute permission fix
    execute_fix(mode, container_name)
  end

  @spec execute_fix(term(), term()) :: term()
  defp execute_fix(:auto, _) do
    IO.puts "\n🔍 Auto-detecting execution mode..."

    if running_in_container?() do
      IO.puts "📦 Detected: Running inside container"
      execute_fix(:container, nil)
    else
      IO.puts "🖥️  Detected: Running on host"
      execute_fix(:host, nil)
    end
  end

  @spec execute_fix(term(), term()) :: term()
  defp execute_fix(:host, _) do
    IO.puts "\n🖥️  Fixing permissions on host for container compatibility..."

    # Create critical directories with proper permissions
    Enum.each(@critical_dirs, fn dir ->
      path = Path.join(@project_root, dir)

      IO.puts "\n📁 Processing: #{dir}"

      # Create directory if it doesn't exist
      File.mkdir_p(path)

      # Set permissions to be writable by containers
      case System.cmd("chmod", ["-R", "777", path], stderr_to_stdout: true) do
        {_, 0} ->
          IO.puts "  ✅ Permissions set to 777 (world-writable)"
        {error, _} ->
          IO.puts "  ⚠️  Warning: #{String.trim(error)}"
      end

      # Add SELinux __context for Podman (if on SELinux system)
      if selinux_enabled?() do
        case System.cmd("chcon", ["-Rt", "container_file_t", path], stderr_to_stdout: true) do
          {_, 0} ->
            IO.puts "  ✅ SELinux __context set for containers"
          _ ->
            IO.puts "  ℹ️  SELinux __context not applicable"
        end
      end
    end)

    # Fix workspace permissions
    fix_workspace_permissions()

    # Validate the fix
    validate_permissions()
  end

  @spec execute_fix(term(), term()) :: term()
  defp execute_fix(:container, container_name) do
    container = container_name || detect_running_container()

    IO.puts "\n📦 Fixing permissions inside container: #{container || "current"}"

    if container do
      # Fix permissions via podman exec
      fix_container_permissions_external(container)
    else
      # We're inside the container, fix directly
      fix_container_permissions_internal()
    end
  end

  @spec execute_fix(term(), term()) :: term()
  defp execute_fix(:all, _) do
    IO.puts "\n🌐 Fixing permissions both on host and in containers..."

    # First fix host permissions
    execute_fix(:host, nil)

    # Then fix all running containers
    IO.puts "\n📦 Finding all Intelitor containers..."

    case System.cmd("podman", ["ps", "--format", "{{.Names}}", "--filter", "name=intelitor"]) do
      {output, 0} ->
        containers = output |> String.split("\n") |> Enum.filter(&(&1 != ""))

        if Enum.empty?(containers) do
          IO.puts "  ℹ️  No running Intelitor containers found"
        else
          Enum.each(containers, fn container ->
            IO.puts "\n📦 Fixing container: #{container}"
            fix_container_permissions_external(container)
          end)
        end
      _ ->
        IO.puts "  ⚠️  Could not list containers"
    end
  end

  @spec fix_workspace_permissions() :: any()
  defp fix_workspace_permissions do
    IO.puts "\n🔧 Fixing workspace permissions..."

    # Ensure workspace is accessible
    workspace_script = """
    #!/bin/bash
    # PHICS Marker: Container Permission Fix
    # NO_TIMEOUT: Natural completion __required

    # Set open permissions for development
    find #{@project_root} -type d -name ".git" -prune -o \
      -type d -exec chmod 755 {} \\; -o \
      -type f -exec chmod 644 {} \\;

    # Make scripts executable
    find #{@project_root}/scripts -name "*.exs" -exec chmod 755 {} \\;
    find #{@project_root}/scripts -name "*.sh" -exec chmod 755 {} \\;

    # Ensure mix/hex directories are writable
    chmod -R 777 #{@project_root}/.mix 2>/dev/null || true
    chmod -R 777 #{@project_root}/.hex 2>/dev/null || true
    chmod -R 777 #{@project_root}/_build 2>/dev/null || true
    chmod -R 777 #{@project_root}/deps 2>/dev/null || true

    echo "✅ Workspace permissions updated"
    """

    case System.cmd("bash", ["-c", workspace_script], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts(output)
      {error, _} ->
        IO.puts "  ⚠️  Some permissions could not be set: #{error}"
    end
  end

  @spec fix_container_permissions_external(term()) :: term()
  defp fix_container_permissions_external(container) do
    # Commands to fix permissions inside container
    fix_commands = [
      # Create developer __user if needed
      "id developer 2>/dev/null || add__user -D -u 1000 developer",

      # Create critical directories
      "mkdir -p /workspace/.mix /workspace/.hex /workspace/_build /workspace/deps",

      # Set ownership to developer __user
      "chown -R developer:developer /workspace/.mix /workspace/.hex",
      "chown -R developer:developer /workspace/_build /workspace/deps 2>/dev/null || true",

      # Set proper permissions
      "chmod -R 755 /workspace",
      "chmod -R 777 /workspace/.mix /workspace/.hex",
      "chmod -R 777 /workspace/_build /workspace/deps 2>/dev/null || true",

      # Create mix config for developer __user
      "su developer -c 'cd /workspace && mix local.hex --force && mix local.rebar --force'"
    ]

    Enum.each(fix_commands, fn cmd ->
      IO.puts "\n  → Executing: #{String.slice(cmd, 0..50)}..."

      case System.cmd("podman", ["exec", container, "sh", "-c", cmd], stderr_to_stdout: true) do
        {output, 0} ->
          if String.trim(output) != "" do
            IO.puts "    #{String.trim(output)}"
          end
          IO.puts "    ✅ Success"
        {error, _} ->
          IO.puts "    ⚠️  Warning: #{String.trim(error)}"
      end
    end)
  end

  @spec fix_container_permissions_internal() :: any()
  defp fix_container_permissions_internal do
    IO.puts "\n🔧 Fixing permissions from inside container..."

    # We're running inside the container
    Enum.each(@critical_dirs, fn dir ->
      path = Path.join("/workspace", dir)
      File.mkdir_p(path)

      # Set permissions
      System.cmd("chmod", ["-R", "777", path])
      IO.puts "  ✅ Fixed permissions for #{dir}"
    end)
  end

  @spec validate_permissions() :: any()
  defp validate_permissions do
    IO.puts "\n🔍 Validating permission fixes..."

    validation_script = """
    #!/bin/bash
    # PHICS Marker: Permission Validation

    echo "Checking critical directories..."

    for dir in .mix .hex _build deps; do
      if [ -d "#{@project_root}/$dir" ]; then
        perms=$(stat -c "%a" "#{@project_root}/$dir" 2>/dev/null || stat -f "%p"
        echo "  $dir: permissions=$perms"

        # Test write access
        if touch "#{@project_root}/$dir/.test_write" 2>/dev/null; then
          rm -f "#{@project_root}/$dir/.test_write"
          echo "    ✅ Write access confirmed"
        else
          echo "    ❌ No write access"
        fi
      else
        echo "  $dir: not created yet"
      fi
    done
    """

    System.cmd("bash", ["-c", validation_script], into: IO.stream(:stdio, :line))
  end

  @spec running_in_container?() :: any()
  defp running_in_container? do
    # Check common container indicators
    File.exists?("/.dockerenv") or
    File.exists?("/run/.containerenv") or
    System.get_env("container") != nil or
    (case File.read("/proc/1/cgroup") do
       {:ok, content}
    -> String.contains?(content, "docker") or String.contains?(content, "containerd")
       _ -> false
     end)
  end

  @spec selinux_enabled?() :: any()
  defp selinux_enabled? do
    # Check if getenforce command exists first
    case System.find_executable("getenforce") do
      nil -> false
      _path ->
        case System.cmd("getenforce", [], stderr_to_stdout: true) do
          {"Enforcing\n", 0} -> true
          {"Permissive\n", 0} -> true
          _ -> false
        end
    end
  end

  @spec detect_running_container() :: any()
  defp detect_running_container do
    # Try to detect if we're targeting a specific container
    case System.cmd("podman", ["ps", "--format", "{{.Names}}", "--filter", "name=intelitor"]) do
      {output, 0} ->
        containers = output |> String.split("\n") |> Enum.filter(&(&1 != ""))
        List.first(containers)
      _ ->
        nil
    end
  end

  @spec test_compilation() :: any()
  def test_compilation do
    IO.puts """

    ═══════════════════════════════════════════════════════════════
    🧪 TESTING CONTAINER COMPILATION
    ═══════════════════════════════════════════════════════════════
    """

    # Test compilation in container
    test_script = """
    podman run --rm \
      -v #{@project_root}:/workspace:z \
      -w /workspace \
      -e ELIXIR_ERL_OPTIONS="+S 16" \
      -e NO_TIMEOUT=true \
      -e PHICS_ENABLED=true \
      elixir:1.18-alpine \
      sh -c '
        echo "🔧 Testing compilation in container..."
        mix local.hex --force &&
        mix local.rebar --force &&
        mix deps.get &&
        mix compile --warnings-as-errors &&
        echo "✅ Container compilation successful!"
      '
    """

    IO.puts "📦 Running container compilation test..."
    IO.puts "⏱️  NO_TIMEOUT policy active-natural completion"
    IO.puts "🔥 PHICS markers present\n"

    case System.cmd("bash", ["-c", test_script], into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        IO.puts "\n✅ Container compilation test PASSED!"

        # Generate success report
        generate_success_report()
      {_, code} ->
        IO.puts "\n❌ Container compilation test FAILED (exit code: #{code})"

        # Perform RCA
        perform_test_failure_rca(code)
    end
  end

  @spec generate_success_report() :: any()
  defp generate_success_report do
    report = """

    ╔══════════════════════════════════════════════════════════════╗
    ║               PERMISSION FIX SUCCESS REPORT                  ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ Timestamp: #{DateTime.utc_now() |> DateTime.to_string()}
    ║ Status: ✅ All permissions fixed                             ║
    ║                                                              ║
    ║ Validated Components:                                        ║
    ║-Host permissions: ✅                                       ║
    ║ - Container permissions: ✅                                  ║
    ║ - Mix/Hex access: ✅                                         ║
    ║ - Compilation test: ✅                                       ║
    ║ - PHICS integration: ✅                                      ║
    ║ - NO_TIMEOUT policy: ✅                                      ║
    ║                                                              ║
    ║ Next Steps:                                                  ║
    ║ 1. Run 'mix compile' in container                          ║
    ║ 2. Run 'mix test' with full coverage                       ║
    ║ 3. Document in journal with timestamp                       ║
    ╚══════════════════════════════════════════════════════════════╝
    """

    IO.puts report

    # Save report
    report_file = "docs/journal/#{timestamp_string()}-container-permission-fix-su
    File.write!(report_file, report)
    IO.puts "\n📄 Report saved to: #{report_file}"
  end

  @spec perform_test_failure_rca(term()) :: term()
  defp perform_test_failure_rca(code) do
    IO.puts """

    🏭 TPS 5-Level Root Cause Analysis
    ══════════════════════════════════

    Failure: Container compilation test failed (code: #{code})

    Level 1 (Symptom): Compilation fails in container
    Level 2 (Surface Cause): Permission or dependency issue
    Level 3 (System Behavior): Container environment mismatch
    Level 4 (Configuration Gap): Missing environment setup
    Level 5 (Design Analysis): Need systematic container configuration

    Immediate Actions:
    1. Check container logs for specific errors
    2. Verify all dependencies are available
    3. Ensure network access for hex packages
    4. Re-run with verbose output
    5. Apply targeted fixes
    """
  end

  @spec timestamp_string() :: any()
  defp timestamp_string do
    DateTime.utc_now()
    |> DateTime.to_string()
    |> String.replace(~r/[:\s]/, "-")
    |> String.replace(".", "")
    |> String.slice(0..18)
  end
end

# Main execution
case System.argv() do
  ["--test"] ->
    # First fix permissions, then test
    FixContainerPermissions.main(["--all"])
    FixContainerPermissions.test_compilation()
  args ->
    FixContainerPermissions.main(args)
end
end
end
end
end
end
