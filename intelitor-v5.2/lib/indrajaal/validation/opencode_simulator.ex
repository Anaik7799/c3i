defmodule Indrajaal.Validation.OpenCodeSimulator do
  @moduledoc """
  OpenCode simulation for offline development and fallback scenarios.

  Provides realistic simulation of OpenCode API responses when the live API
  is unavailable or for development/testing purposes.
  """

  require Logger

  @doc """
  Validates Elixir code and returns validation results.

  This is a simplified validation function used as a fallback when
  the OpenCode API is unavailable.

  ## Examples

      iex> OpenCodeSimulator.validate("def hello, do: :world")
      {:ok, %{valid: true, issues: [], confidence: 0.85}}
  """
  @spec validate(String.t()) :: {:ok, map()}
  def validate(code) do
    Logger.info("Validating code with OpenCode simulator", code_length: String.length(code))

    # Basic validation checks
    valid = String.contains?(code, "def") && !String.contains?(code, "invalid")
    issues = detect_simple_issues(code)
    confidence = calculate_validation_confidence(code, issues)

    result = %{
      valid: valid,
      issues: issues,
      confidence: confidence,
      validator: :opencode_simulator
    }

    {:ok, result}
  end

  @doc """
  Simulates OpenCode analysis for given code and analysis type.

  ## Examples

      iex> OpenCodeSimulator.simulate_analysis("def hello, do: :world", :compilation)
      {:ok, %{status: :completed, findings: [], confidence: 85.0}}
  """
  @spec simulate_analysis(String.t(), atom()) :: {:ok, map()} | {:error, atom()}
  def simulate_analysis(code, analysis_type) do
    Logger.info("Simulating OpenCode analysis",
      type: analysis_type,
      code_length: String.length(code)
    )

    findings = generate_simulated_findings(code, analysis_type)
    confidence = calculate_simulated_confidence(code, findings)

    result = %{
      status: :completed,
      findings: findings,
      confidence: confidence,
      simulation_mode: true,
      ep110_risk: false
    }

    {:ok, result}
  end

  # Private functions for simulation logic

  defp generate_simulated_findings(code, :compilation) do
    findings = []

    findings =
      if String.contains?(code, "undefined_variable") do
        [
          %{
            type: :error,
            message: "Undefined variable 'undefined_variable'",
            file: "simulated.ex",
            line: find_line_number(code, "undefined_variable"),
            severity: :high
          }
          | findings
        ]
      else
        findings
      end

    findings =
      if String.contains?(code, "_unused") and not String.contains?(code, "def func(_unused") do
        [
          %{
            type: :warning,
            message: "Variable '_unused' is unused",
            file: "simulated.ex",
            line: find_line_number(code, "_unused"),
            severity: :low
          }
          | findings
        ]
      else
        findings
      end

    findings
  end

  defp generate_simulated_findings(code, :security_analysis) do
    findings = []

    findings =
      if String.contains?(code, "String.to_atom") do
        [
          %{
            type: :warning,
            message: "Potential atom exhaustion via String.to_atom/1",
            file: "simulated.ex",
            line: find_line_number(code, "String.to_atom"),
            severity: :medium
          }
          | findings
        ]
      else
        findings
      end

    findings
  end

  defp generate_simulated_findings(_code, _type), do: []

  defp calculate_simulated_confidence(code, findings) do
    base_confidence = 85.0

    # Reduce confidence based on code complexity
    complexity_penalty = min(String.length(code) / 100, 10.0)

    # Reduce confidence based on findings
    findings_penalty = length(findings) * 5.0

    max(base_confidence - complexity_penalty - findings_penalty, 60.0)
  end

  defp find_line_number(code, search_term) do
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find(fn {line, _index} -> String.contains?(line, search_term) end)
    |> case do
      {_line, index} -> index
      nil -> 1
    end
  end

  # Helper functions for validate/1

  defp detect_simple_issues(code) do
    issues = []

    # Check for common syntax issues
    issues =
      if String.contains?(code, "undefined") do
        ["Potential undefined variable or function" | issues]
      else
        issues
      end

    issues =
      if String.contains?(code, "TODO") or String.contains?(code, "FIXME") do
        ["Code contains TODO or FIXME markers" | issues]
      else
        issues
      end

    issues
  end

  defp calculate_validation_confidence(code, issues) do
    base = 0.85
    penalty = length(issues) * 0.1
    complexity_factor = min(String.length(code) / 1000, 0.1)

    max(base - penalty - complexity_factor, 0.5)
  end
end
