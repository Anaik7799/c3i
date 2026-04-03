defmodule Indrajaal.Validation.FPPS do
  @moduledoc """
  Five-Point Pattern System (FPPS) Orchestrator.
  Coordinates 5 validation methods to ensure zero defects with high confidence.

  ## STAMP Compliance
  - SC-VAL-003: 100% Consensus required - all 5 methods MUST agree
  - SC-VAL-004: Halt on disagreement
  - SC-VAL-005: Complete log analysis
  - SC-MULTILINE-001: Multiline entries joined before validation

  ## Preprocessing Pipeline
  Raw log content is normalized via `ContextWindow.normalize/1` before
  being passed to the 5 methods. This joins multiline error entries into
  logical lines, ensuring all methods see consistent line boundaries and
  produce the same category counts.

  Task 22.2.3.1.1, 44.1.0.0.0
  """
  require Logger

  alias Indrajaal.Validation.Consensus
  alias Indrajaal.Validation.ContextWindow
  alias Indrajaal.Validation.FPPSStatistical
  alias Indrajaal.Validation.FPPSBinary
  alias Indrajaal.Validation.FPPSLineByLine

  @doc """
  Validates using all 5 FPPS methods against compilation log content.

  The log content is first normalized via `ContextWindow.normalize/1` to
  join multiline entries into logical lines (SC-MULTILINE-001). All methods
  then analyse the SAME normalized input and count the same 10 error
  categories + 5 warning categories using independent techniques:
    1. Pattern  — regex matching (compile-time patterns)
    2. AST      — abstract-syntax-tree analysis of embedded code snippets
    3. Statistical — statistical classification of log lines
    4. Binary   — byte-level scanning (no regex, pure binary matching)
    5. LineByLine — per-line heuristic classification

  All methods must agree on counts for consensus (SC-VAL-003).
  """
  def validate(log_content, opts \\ []) do
    # SC-MULTILINE-001: Normalize multiline entries before validation
    normalized = ContextWindow.normalize(log_content)

    results = [
      # Method 1: Pattern matching (regex)
      Indrajaal.Validation.Methods.Pattern.validate(normalized),

      # Method 2: AST validation (semantic parsing)
      Indrajaal.Validation.Methods.AST.validate(normalized),

      # Method 3: Statistical analysis (frequency + anomaly)
      FPPSStatistical.validate_log_content(normalized),

      # Method 4: Binary verification (byte-level scanning)
      FPPSBinary.validate_log_content(normalized),

      # Method 5: Line-by-line classification (heuristic)
      FPPSLineByLine.validate_log_content(normalized)
    ]

    case Consensus.check(results, opts) do
      {:ok, consensus} ->
        Logger.info("FPPS Consensus achieved: #{inspect(consensus)}")
        {:ok, %{consensus: consensus, individual_results: results}}

      {:error, :consensus_failed, diagnostics} ->
        Logger.error("FPPS Consensus FAILED - halting per SC-VAL-004")
        Logger.error("Diagnostics: #{inspect(diagnostics)}")
        {:error, :consensus_failed, %{results: results, diagnostics: diagnostics}}

      {:error, reason} ->
        Logger.error("FPPS Consensus error: #{inspect(reason)}")
        {:error, reason, results}
    end
  end

  @doc """
  Validates using all 5 FPPS methods with rich artifact reports.

  Unlike `validate/1` which analyses a log string for consensus,
  this function runs deep validation on the actual build artifacts:
  binary verification of .beam files, source-code line analysis, etc.

  Returns per-method rich reports without requiring consensus.
  Use this for detailed diagnostics, not for the consensus gate.
  """
  def validate_artifacts(log_content, opts \\ []) do
    env = Keyword.get(opts, :env, :dev)

    %{
      pattern: Indrajaal.Validation.Methods.Pattern.validate(log_content),
      ast: Indrajaal.Validation.Methods.AST.validate(log_content),
      statistical: validate_statistical_artifact(log_content),
      binary: validate_binary_artifact(env),
      line_by_line: validate_line_by_line_artifact()
    }
  end

  # ── Rich artifact validation (non-consensus) ──────────────────────────

  defp validate_statistical_artifact(log_content) do
    temp_path =
      Path.join(System.tmp_dir!(), "fpps-log-#{:erlang.unique_integer([:positive])}.log")

    case File.write(temp_path, log_content) do
      :ok ->
        result = FPPSStatistical.validate_log_file(temp_path)
        File.rm(temp_path)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_binary_artifact(env) do
    FPPSBinary.validate_beam_files("indrajaal", env: env)
  end

  defp validate_line_by_line_artifact do
    FPPSLineByLine.validate_elixir_files("lib/", exclude: ["_build/**", "deps/**"])
  end
end
