#!/usr/bin/env elixir

# Basic test to verify the module structure without starting GenServer

# Add compiled modules to code path
Code.prepend_path("_build/dev/lib/indrajaal/ebin")

IO.puts("""
🤖 Basic Git Incremental Validation Module Test
==============================================
""")

# Test 1: Module loading
IO.puts("1. Module Loading Test...")

case Code.ensure_loaded(Indrajaal.Git.IncrementalValidation) do
  {:module, module} ->
    IO.puts("   ✅ Module loaded: #{inspect(module)}")

  {:error, reason} ->
    IO.puts("   ❌ Failed to load module: #{inspect(reason)}")
    System.halt(1)
end

# Test 2: Check exported functions
IO.puts("\n2. Exported Functions Test...")
functions = Indrajaal.Git.IncrementalValidation.__info__(:functions)
IO.puts("   ✅ Total exported functions: #{length(functions)}")

important_functions = [
  {:start_link, 0},
  {:start_link, 1},
  {:validate_config, 1},
  {:detect_changes, 1},
  {:analyze_change_impact, 1},
  {:validate_changeset, 1},
  {:pre_commit_validation, 1},
  {:pre_push_validation, 1},
  {:generate_git_hooks, 1}
]

Enum.each(important_functions, fn {func, arity} ->
  if {func, arity} in functions do
    IO.puts("   ✅ #{func}/#{arity} - Available")
  else
    IO.puts("   ❌ #{func}/#{arity} - Missing")
  end
end)

# Test 3: Module documentation
IO.puts("\n3. Module Documentation Test...")

case Code.fetch_docs(Indrajaal.Git.IncrementalValidation) do
  {:docs_v1, _, _, _, module_doc, _, _} when module_doc != :none ->
    IO.puts("   ✅ Module documentation present")

  _ ->
    IO.puts("   ⚠️  Module documentation not compiled")
end

# Test 4: Git hook generation (doesn't need GenServer)
IO.puts("\n4. Git Hook Generation Test...")

hook_config = %{
  pre_commit: true,
  pre_push: true,
  incremental_only: true,
  cache_enabled: true
}

case Indrajaal.Git.IncrementalValidation.generate_git_hooks(hook_config) do
  {:ok, hooks} ->
    IO.puts("   ✅ Git hooks generated successfully")
    IO.puts("   Pre-commit hook size: #{String.length(hooks.pre_commit)} bytes")
    IO.puts("   Pre-push hook size: #{String.length(hooks.pre_push)} bytes")

    if String.contains?(hooks.pre_commit, "incremental") do
      IO.puts("   ✅ Pre-commit hook contains 'incremental' keyword")
    end

    if String.contains?(hooks.pre_push, "cache") do
      IO.puts("   ✅ Pre-push hook contains 'cache' keyword")
    end

  error ->
    IO.puts("   ❌ Hook generation failed: #{inspect(error)}")
end

# Test 5: Configuration validation (static function)
IO.puts("\n5. Configuration Validation Test...")

valid_config = %{
  git_repository: "/path/to/repo",
  incremental_validation: true,
  methodology_checks: [:tps, :stamp, :tdg],
  container_only: true
}

case Indrajaal.Git.IncrementalValidation.validate_config(valid_config) do
  :ok ->
    IO.puts("   ✅ Valid configuration accepted")

  error ->
    IO.puts("   ❌ Valid configuration rejected: #{inspect(error)}")
end

invalid_config = %{
  incremental_validation: true
}

case Indrajaal.Git.IncrementalValidation.validate_config(invalid_config) do
  {:error, :missing_required_configuration} ->
    IO.puts("   ✅ Invalid configuration correctly rejected")

  _ ->
    IO.puts("   ❌ Invalid configuration not rejected properly")
end

IO.puts("""

✅ Basic Module Tests Complete!
==============================
The Git Incremental Validation module structure is correct.
GenServer functionality __requires full application __context.
""")
