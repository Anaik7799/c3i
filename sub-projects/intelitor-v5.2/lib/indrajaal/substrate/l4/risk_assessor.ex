defmodule Indrajaal.Substrate.L4.RiskAssessor do
  @moduledoc """
  L4 Risk Assessor — Risk quantification engine for environmental intelligence.

  Computes risk scores using the FMEA Risk Priority Number (RPN) model:
    RPN = Severity × Occurrence × Detection

  Each risk is classified into a severity tier and mapped to a mitigation
  priority. The L4 intelligence layer uses risk assessments to recommend
  adaptive responses and resource allocation.

  ## Severity Tiers
  - P0 (CRITICAL): RPN ≥ 200 — immediate action
  - P1 (HIGH):     RPN 100–199 — urgent response
  - P2 (MEDIUM):   RPN 50–99 — planned remediation
  - P3 (LOW):      RPN < 50 — monitor only

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FMEA-002: RPN MUST use S×O×D formula — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type priority :: :p0_critical | :p1_high | :p2_medium | :p3_low

  @type risk_entry :: %{
          id: String.t(),
          label: String.t(),
          severity: pos_integer(),
          occurrence: pos_integer(),
          detection: pos_integer(),
          rpn: pos_integer(),
          priority: priority(),
          mitigation: String.t()
        }

  @type t :: %__MODULE__{
          risks: [risk_entry()],
          label: String.t()
        }

  defstruct risks: [],
            label: "default"

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok, %__MODULE__{label: label}}
    end
  end

  @spec assess(t(), String.t(), pos_integer(), pos_integer(), pos_integer(), String.t()) :: t()
  def assess(%__MODULE__{} = state, label, severity, occurrence, detection, mitigation)
      when is_binary(label) and is_binary(mitigation) do
    s = clamp_scale(severity)
    o = clamp_scale(occurrence)
    d = clamp_scale(detection)
    rpn = s * o * d

    entry = %{
      id: generate_id(),
      label: label,
      severity: s,
      occurrence: o,
      detection: d,
      rpn: rpn,
      priority: classify(rpn),
      mitigation: mitigation
    }

    %{state | risks: state.risks ++ [entry]}
  end

  @spec critical_risks(t()) :: [risk_entry()]
  def critical_risks(%__MODULE__{risks: risks}) do
    risks
    |> Enum.filter(fn r -> r.priority == :p0_critical end)
    |> Enum.sort_by(& &1.rpn, :desc)
  end

  @spec max_rpn(t()) :: non_neg_integer()
  def max_rpn(%__MODULE__{risks: []}), do: 0

  def max_rpn(%__MODULE__{risks: risks}) do
    Enum.max_by(risks, & &1.rpn).rpn
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    by_priority =
      Enum.group_by(state.risks, & &1.priority)
      |> Map.new(fn {k, v} -> {k, length(v)} end)

    %{
      label: state.label,
      total_risks: length(state.risks),
      max_rpn: max_rpn(state),
      critical_count: Map.get(by_priority, :p0_critical, 0),
      high_count: Map.get(by_priority, :p1_high, 0),
      medium_count: Map.get(by_priority, :p2_medium, 0),
      low_count: Map.get(by_priority, :p3_low, 0)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp classify(rpn) when rpn >= 200, do: :p0_critical
  defp classify(rpn) when rpn >= 100, do: :p1_high
  defp classify(rpn) when rpn >= 50, do: :p2_medium
  defp classify(_rpn), do: :p3_low

  defp clamp_scale(v) when is_integer(v), do: min(10, max(1, v))
  defp clamp_scale(v) when is_float(v), do: min(10, max(1, round(v)))
  defp clamp_scale(_), do: 1

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end
end
