defmodule Indrajaal.Validation.Consensus do
  @moduledoc """
  FPPS 5-Method Consensus Engine.

  WHAT: Verifies that all 5 FPPS validation methods agree on the same
  error and warning category counts. Provides diagnostic detail on failures.

  WHY: SC-VAL-003 requires 100% consensus. SC-VAL-004 requires halt on
  disagreement. This module enforces both constraints and reports which
  methods disagree to accelerate root-cause analysis.

  CONSTRAINTS:
  - SC-VAL-003: 100% consensus required across all 5 methods
  - SC-VAL-004: Halt on disagreement — Emergency protocol

  Task 22.2.3.1.2, 46.2.0.0.0
  """
  require Logger

  @expected_method_count 5

  @doc """
  Checks consensus across all FPPS method results.

  Returns `{:ok, %{errors: n, warnings: m}}` if all methods agree,
  or `{:error, :consensus_failed, diagnostics}` with detailed failure info.

  ## Options

  - `:min_agreement` — minimum number of methods that must agree for quorum
    mode (default: `@expected_method_count`, i.e. strict unanimity). When set
    to e.g. 3, at least 3 out of 5 methods must agree on both error and
    warning counts for consensus to pass.
  """
  def check(results, opts \\ [])

  def check(results, opts) when is_list(results) do
    min_agreement = Keyword.get(opts, :min_agreement, @expected_method_count)

    error_list = Enum.map(results, & &1.errors)
    warning_list = Enum.map(results, & &1.warnings)

    errors_unique = Enum.uniq(error_list)
    warnings_unique = Enum.uniq(warning_list)

    cond do
      length(results) < @expected_method_count ->
        Logger.error(
          "[Consensus] Incomplete: #{length(results)}/#{@expected_method_count} methods"
        )

        {:error, :incomplete_methods}

      length(errors_unique) == 1 and length(warnings_unique) == 1 ->
        {:ok, %{errors: hd(errors_unique), warnings: hd(warnings_unique)}}

      min_agreement < @expected_method_count ->
        # Quorum mode: check if at least min_agreement methods agree
        error_majority = majority_entry(error_list)
        warning_majority = majority_entry(warning_list)

        if elem(error_majority, 1) >= min_agreement and
             elem(warning_majority, 1) >= min_agreement do
          {:ok,
           %{
             errors: elem(error_majority, 0),
             warnings: elem(warning_majority, 0),
             mode: :quorum,
             agreement: min(elem(error_majority, 1), elem(warning_majority, 1))
           }}
        else
          diagnostics = build_diagnostics(results, error_list, warning_list)
          Logger.error("[Consensus] Quorum FAILED — #{diagnostics.disagreement_summary}")
          {:error, :consensus_failed, diagnostics}
        end

      true ->
        diagnostics = build_diagnostics(results, error_list, warning_list)

        Logger.error("[Consensus] FAILED — #{diagnostics.disagreement_summary}")

        {:error, :consensus_failed, diagnostics}
    end
  end

  def check(_results, _opts) do
    {:error, :invalid_input}
  end

  @doc """
  Returns true if all results have identical error and warning counts.
  """
  def consensus?(results) when is_list(results) do
    match?({:ok, _}, check(results))
  end

  def consensus?(_), do: false

  # ---------------------------------------------------------------------------
  # Private: Diagnostics
  # ---------------------------------------------------------------------------

  defp build_diagnostics(results, error_list, warning_list) do
    methods = Enum.map(results, &method_name/1)

    error_by_method = Enum.zip(methods, error_list)
    warning_by_method = Enum.zip(methods, warning_list)

    error_disagreement = length(Enum.uniq(error_list)) > 1
    warning_disagreement = length(Enum.uniq(warning_list)) > 1

    summary_parts =
      []
      |> then(fn parts ->
        if error_disagreement do
          values = Enum.map(error_by_method, fn {m, v} -> "#{m}=#{v}" end)
          ["errors: #{Enum.join(values, ", ")}" | parts]
        else
          parts
        end
      end)
      |> then(fn parts ->
        if warning_disagreement do
          values = Enum.map(warning_by_method, fn {m, v} -> "#{m}=#{v}" end)
          ["warnings: #{Enum.join(values, ", ")}" | parts]
        else
          parts
        end
      end)

    %{
      method_count: length(results),
      error_by_method: error_by_method,
      warning_by_method: warning_by_method,
      error_disagreement: error_disagreement,
      warning_disagreement: warning_disagreement,
      majority_errors: majority_value(error_list),
      majority_warnings: majority_value(warning_list),
      disagreement_summary: Enum.join(summary_parts, "; ")
    }
  end

  defp method_name(%{method: m}), do: Atom.to_string(m)
  defp method_name(_), do: "unknown"

  defp majority_value(values) do
    values
    |> Enum.frequencies()
    |> Enum.max_by(fn {_val, count} -> count end)
    |> elem(0)
  end

  # Returns {value, count} for the most frequent value
  defp majority_entry(values) do
    values
    |> Enum.frequencies()
    |> Enum.max_by(fn {_val, count} -> count end)
  end
end
