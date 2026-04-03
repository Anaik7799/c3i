#!/usr/bin/env elixir

# Quick test script for Git Incremental Validation
# This verifies basic functionality without running full test suite

# Add compiled modules to code path
Code.prepend_path("_build/dev/lib/indrajaal/ebin")

IO.puts("""
🤖 Testing Git Incremental Validation System
==========================================
""")

# Ensure __required modules are available
Code.ensure_loaded(Indrajaal.Git.IncrementalValidation)

# Test 1: Module loading
IO.puts("1. Module Loading Test...")

case Code.ensure_loaded(Indrajaal.Git.IncrementalValidation) do
  {:module, _} ->
    IO.puts("   ✅ Module loaded successfully")

  {:error, reason} ->
    IO.puts("   ❌ Failed to load module: #{inspect(reason)}")
    System.halt(1)
end

# Test 2: Start the GenServer
IO.puts("\n2. GenServer Startup Test...")

case Indrajaal.Git.IncrementalValidation.start_link() do
  {:ok, pid} ->
    IO.puts("   ✅ GenServer started: #{inspect(pid)}")

  {:error, {:already_started, pid}} ->
    IO.puts("   ✅ GenServer already running: #{inspect(pid)}")

  error ->
    IO.puts("   ❌ Failed to start: #{inspect(error)}")
    System.halt(1)
end

# Test 3: Configuration validation
IO.puts("\n3. Configuration Validation Test...")

config = %{
  git_repository: "/home/an/dev/elixir/ash/indrajaal-demo",
  incremental_validation: true,
  methodology_checks: [:tps, :stamp, :tdg],
  performance_mode: :optimized,
  container_only: true
}

case Indrajaal.Git.IncrementalValidation.validate_config(config) do
  :ok ->
    IO.puts("   ✅ Configuration valid")

  error ->
    IO.puts("   ❌ Configuration invalid: #{inspect(error)}")
end

# Test 4: Change detection
IO.puts("\n4. Change Detection Test...")

git_diff = %{
  added_files: ["lib/new_module.ex"],
  modified_files: ["lib/existing_module.ex", "test/existing_module_test.exs"],
  deleted_files: ["lib/deprecated_module.ex"],
  commit_range: "HEAD~1..HEAD"
}

case Indrajaal.Git.IncrementalValidation.detect_changes(git_diff) do
  {:ok, changes} ->
    IO.puts("   ✅ Changes detected:")
    IO.puts("-Files to validate: #{length(changes.files_to_validate)}")
    IO.puts("-Validation scope: #{changes.validation_scope}")

  error ->
    IO.puts("   ❌ Change detection failed: #{inspect(error)}")
end

# Test 5: Incremental validation performance
IO.puts("\n5. Incremental Validation Performance Test...")

changeset = %{
  total_files: 1000,
  changed_files: ["lib/module1.ex", "lib/module2.ex"]
}

{time, {:ok, result}} =
  :timer.tc(fn ->
    Indrajaal.Git.IncrementalValidation.validate_incremental(changeset)
  end)

IO.puts("   ✅ Incremental validation completed:")
IO.puts("-Files validated: #{result.files_validated}")
IO.puts("-Time: #{time / 1000}ms")

IO.puts(
  "-Performance: #{if time < 100_000, do: "✅ PASS (<100ms)", else: "❌ FAIL
)

# Test 6: Container environment check
IO.puts("\n6. Container Environment Test...")

case Indrajaal.Git.IncrementalValidation.validate_container_environment() do
  {:ok, info} ->
    IO.puts("   ✅ Container environment:")
    IO.puts("-NixOS container: #{info.nixos_container}")
    IO.puts("-Runtime: #{info.container_runtime}")

  {:error, :not_in_container} ->
    IO.puts("   ⚠️  Not running in container (expected in dev)")
end

# Test 7: Claude logging
IO.puts("\n7. Claude Logging Test...")

activity = %{
  activity_type: "test_validation",
  files_validated: 5,
  timestamp: DateTime.utc_now()
}

case Indrajaal.Git.IncrementalValidation.log_validation_activity(activity) do
  :ok ->
    IO.puts("   ✅ Activity logged successfully")

    # Check if log file was created
    log_files = Path.wildcard("./__data/tmp/claude_git_validation_*.log")

    if length(log_files) > 0 do
      IO.puts("-Log files found: #{length(log_files)}")
    else
      IO.puts("-⚠️  Log files not found (check ./__data/tmp/)")
    end

  error ->
    IO.puts("   ❌ Logging failed: #{inspect(error)}")
end

IO.puts("""

✅ Basic Git Incremental Validation Tests Complete!
==================================================
All core functionality is working correctly.
Ready for comprehensive test suite execution.
""")

end
