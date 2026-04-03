defmodule Mix.Tasks.Fame.Validate do
  @moduledoc """
  Validates FAME (Fractal Artifact Metadata Enrichment) metadata in Elixir source files.

  WHAT: CLI tool for validating FAME metadata blocks against schema requirements.
  WHY: Enables CI/CD integration for metadata quality gates (P1-HIGH priority).
  CONSTRAINTS: Exit code 1 in strict mode if any failures; non-destructive read-only.

  ## FAME Validation Scope

  This task validates:
  - Required blocks presence (meta, impact, boundaries, evolution for P0 artifacts)
  - Field type compliance against Schema types (Indrajaal.FAME.Schema)
  - Cross-reference integrity (artifact_id format, parent/child relationships)
  - STAMP constraint references validity (SC-XXX-NNN format)

  ## STAMP Compliance
  - SC-FAME-002: All blocks must have validation functions
  - SC-DOC-001: Moduledoc with WHAT/WHY/CONSTRAINTS
  - SC-VAL-001: Patient Mode validation support

  ## AOR Compliance
  - AOR-DOC-001: Read moduledoc before editing
  - AOR-QUA-001: Zero warnings mandatory in strict mode

  ## Usage

      mix fame.validate [path] [options]

  ## Arguments

  - path: File path, directory, or glob pattern (default: "lib/**/*.ex")

  ## Options

  - --strict, -s     P0 artifact validation (all required fields, exit 1 on failure)
  - --json, -j       Output results as JSON for CI/CD integration
  - --fix, -f        Attempt automatic fixes (generates @fame_* stubs) [NOT YET IMPLEMENTED]
  - --verbose, -v    Show detailed validation output per file
  - --summary-only   Only show summary, skip per-file details
  - --help, -h       Show this help message

  ## Examples

      # Validate all lib files
      mix fame.validate

      # Validate specific directory with strict mode
      mix fame.validate lib/indrajaal/accounts --strict

      # Validate single file
      mix fame.validate lib/indrajaal/accounts/user.ex

      # CI/CD mode with JSON output
      mix fame.validate lib/**/*.ex --strict --json

      # Verbose output for debugging
      mix fame.validate lib/indrajaal --verbose

  ## Exit Codes

  - 0: All validations passed (or non-strict mode)
  - 1: Failures detected in strict mode

  ## Example Output

      FAME Validation Report
      ======================
      Checked: 152 files
      Passed: 148
      Failed: 2
      Missing: 2

      Failures:
        lib/indrajaal/accounts/user.ex:
          - @fame_meta.purpose: Required field missing
          - @fame_boundaries.stamp: Empty list not allowed for P0 artifacts
  """

  use Mix.Task

  @shortdoc "Validates FAME metadata in Elixir source files"

  @switches [
    strict: :boolean,
    json: :boolean,
    fix: :boolean,
    verbose: :boolean,
    summary_only: :boolean,
    help: :boolean
  ]

  @aliases [
    s: :strict,
    j: :json,
    f: :fix,
    v: :verbose,
    h: :help
  ]

  @impl Mix.Task
  def run(args) do
    {opts, paths, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    cond do
      opts[:help] ->
        show_help()

      opts[:fix] ->
        Mix.shell().error("Error: --fix is not yet implemented")
        Mix.shell().info("Hint: Use Indrajaal.FAME.Schema.new_minimal/2 to generate FAME stubs")

      true ->
        run_validation(paths, opts)
    end
  end

  # ============================================================================
  # VALIDATION RUNNER
  # ============================================================================

  defp run_validation(paths, opts) do
    pattern = determine_pattern(paths)
    strict = Keyword.get(opts, :strict, false)
    json_output = Keyword.get(opts, :json, false)
    verbose = Keyword.get(opts, :verbose, false)
    summary_only = Keyword.get(opts, :summary_only, false)

    # Run validation
    results = Indrajaal.FAME.Validator.validate_pattern(pattern, strict: strict)
    summary = Indrajaal.FAME.Validator.summarize_results(results)

    if json_output do
      output_json(results, summary)
    else
      output_text(results, summary, verbose: verbose, summary_only: summary_only)
    end

    # Exit with code 1 if strict mode and failures
    if strict and summary.failed > 0 do
      System.at_exit(fn _ -> :ok end)
      Mix.raise("FAME validation failed: #{summary.failed} file(s) with errors")
    end
  end

  defp determine_pattern([]), do: "lib/**/*.ex"

  defp determine_pattern([path | _]) do
    cond do
      String.contains?(path, "*") ->
        path

      File.dir?(path) ->
        Path.join(path, "**/*.ex")

      File.exists?(path) ->
        path

      true ->
        Mix.shell().error("Warning: Path not found: #{path}, using default pattern")
        "lib/**/*.ex"
    end
  end

  # ============================================================================
  # TEXT OUTPUT
  # ============================================================================

  defp output_text(results, summary, opts) do
    verbose = Keyword.get(opts, :verbose, false)
    summary_only = Keyword.get(opts, :summary_only, false)

    Mix.shell().info("")
    Mix.shell().info("FAME Validation Report")
    Mix.shell().info("======================")
    Mix.shell().info("Checked: #{summary.total} files")
    Mix.shell().info("Passed:  #{summary.passed}")
    Mix.shell().info("Failed:  #{summary.failed}")
    Mix.shell().info("Missing: #{summary.missing}")

    unless summary_only do
      # Show failures
      if summary.failed > 0 do
        Mix.shell().info("")
        output_failures(summary.failures)
      end

      # Show missing in verbose mode
      if verbose and summary.missing > 0 do
        Mix.shell().info("")
        Mix.shell().info("Files without FAME metadata:")

        results
        |> Enum.filter(&(&1.status == :missing))
        |> Enum.each(fn r ->
          Mix.shell().info("  #{r.file}")
        end)
      end

      # Show passed files in verbose mode
      if verbose and summary.passed > 0 do
        Mix.shell().info("")
        Mix.shell().info("Passed files:")

        results
        |> Enum.filter(&(&1.status == :passed))
        |> Enum.each(fn r ->
          Mix.shell().info("  [OK] #{r.file}")
        end)
      end
    end

    # Show summary status
    Mix.shell().info("")

    if summary.failed > 0 do
      Mix.shell().error("Status: FAILED")
    else
      Mix.shell().info("Status: PASSED")
    end

    Mix.shell().info("")
  end

  # ============================================================================
  # JSON OUTPUT
  # ============================================================================

  defp output_json(results, summary) do
    output = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      fame_version: "2.0.0-BIO",
      summary: %{
        total: summary.total,
        passed: summary.passed,
        failed: summary.failed,
        missing: summary.missing,
        success_rate: calculate_success_rate(summary)
      },
      files:
        results
        |> Enum.map(fn r ->
          %{
            file: r.file,
            status: Atom.to_string(r.status),
            errors:
              Enum.map(r.errors, fn e ->
                %{
                  field: e.field,
                  message: e.message,
                  severity: Atom.to_string(e.severity)
                }
              end),
            has_fame: r.status != :missing
          }
        end),
      failures:
        summary.failures
        |> Enum.map(fn {file, errors} ->
          %{
            file: file,
            errors:
              Enum.map(errors, fn e ->
                %{field: e.field, message: e.message, severity: Atom.to_string(e.severity)}
              end)
          }
        end)
    }

    json_string = Jason.encode!(output, pretty: true)
    IO.puts(json_string)
  end

  defp calculate_success_rate(%{total: 0}), do: 100.0

  defp calculate_success_rate(%{total: total, passed: passed}) do
    Float.round(passed / total * 100, 2)
  end

  # ============================================================================
  # HELP
  # ============================================================================

  defp show_help do
    Mix.shell().info(@moduledoc)
  end

  # ============================================================================
  # OUTPUT HELPERS
  # ============================================================================

  @spec output_failures(map()) :: nil
  defp output_failures(failures) do
    Mix.shell().error("Failures:")

    Enum.each(failures, fn {file, errors} ->
      output_file_failures(file, errors)
    end)
  end

  @spec output_file_failures(String.t(), list()) :: nil
  defp output_file_failures(file, errors) do
    Mix.shell().error("  #{file}:")

    Enum.each(errors, fn error ->
      severity_prefix = if error.severity == :error, do: "[ERROR]", else: "[WARN]"
      Mix.shell().error("    #{severity_prefix} @fame_#{error.field}: #{error.message}")
    end)
  end
end
