defmodule Indrajaal.Substrate.L5.NormEnforcer do
  @moduledoc """
  ## Design Intent
  L5 substrate norm enforcer — pure functional module that evaluates actions
  against a set of social norms and institutional rules, assigning compliance
  scores and flagging violations.

  Biological metaphor: immune system self/non-self discrimination — norms
  define "self" behaviour; deviations are tagged as foreign and escalated.

  Algorithm:
    - Each norm has: category, weight, predicate_key, and severity.
    - `evaluate/2` accepts an action map and checks each applicable norm.
    - Compliance score = weighted average of norm pass rates (0.0–1.0).
    - Violations carry severity: :critical | :high | :medium | :low.
    - Norm evaluation is predicate-based via a built-in dispatch table.

  Built-in predicates:
    - `:require_actor` — action must have non-nil `actor` field.
    - `:require_audit` — action params must not set `skip_audit: true`.
    - `:require_justification` — action must carry a non-empty `justification`.
    - `:no_bulk_delete` — action type must not be `:bulk_delete`.
    - `:require_approval` — action must carry `approved: true` in params.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-S5-002: VSM S5 identity and ethos — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type severity :: :critical | :high | :medium | :low

  @type norm :: %{
          id: String.t(),
          category: atom(),
          predicate: atom(),
          weight: float(),
          severity: severity()
        }

  @type violation :: %{
          norm_id: String.t(),
          category: atom(),
          severity: severity(),
          reason: String.t()
        }

  @type eval_result :: %{
          compliant: boolean(),
          score: float(),
          violations: [violation()]
        }

  @type t :: %__MODULE__{
          norms: [norm()],
          eval_count: non_neg_integer()
        }

  defstruct norms: [],
            eval_count: 0

  # Default norms applied when no custom norms are given
  @default_norms [
    %{
      id: "N-001",
      category: :accountability,
      predicate: :require_actor,
      weight: 1.0,
      severity: :critical
    },
    %{
      id: "N-002",
      category: :auditability,
      predicate: :require_audit,
      weight: 0.9,
      severity: :high
    },
    %{
      id: "N-003",
      category: :destructiveness,
      predicate: :no_bulk_delete,
      weight: 0.8,
      severity: :critical
    }
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new NormEnforcer.

  Options:
    - `:norms` — list of norm maps (defaults to built-in norms when omitted).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    norms = Keyword.get(opts, :norms, @default_norms)

    cond do
      not is_list(norms) ->
        {:error, "norms must be a list"}

      not Enum.all?(norms, &valid_norm?/1) ->
        {:error, "each norm requires id, category, predicate, weight (0..1), severity"}

      true ->
        {:ok, %__MODULE__{norms: norms}}
    end
  end

  @doc "Add a norm to the enforcer."
  @spec add_norm(t(), norm()) :: {:ok, t()} | {:error, String.t()}
  def add_norm(%__MODULE__{} = state, norm) do
    if valid_norm?(norm) do
      {:ok, %{state | norms: [norm | state.norms]}}
    else
      {:error, "invalid norm structure"}
    end
  end

  @doc """
  Evaluate an action against all registered norms.

  `action` must be a map with at least `%{type: atom(), actor: any(), params: map()}`.
  Returns an `eval_result` with compliance score and any violations.
  """
  @spec evaluate(t(), map()) :: {eval_result(), t()}
  def evaluate(%__MODULE__{} = state, action) when is_map(action) do
    violations =
      Enum.flat_map(state.norms, fn norm ->
        if passes_predicate?(norm.predicate, action) do
          []
        else
          [
            %{
              norm_id: norm.id,
              category: norm.category,
              severity: norm.severity,
              reason: predicate_reason(norm.predicate)
            }
          ]
        end
      end)

    score = compute_score(state.norms, violations)

    result = %{
      compliant: Enum.empty?(violations),
      score: Float.round(score, 4),
      violations: violations
    }

    {result, %{state | eval_count: state.eval_count + 1}}
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      norm_count: length(state.norms),
      eval_count: state.eval_count,
      norm_ids: Enum.map(state.norms, & &1.id)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec passes_predicate?(atom(), map()) :: boolean()
  defp passes_predicate?(:require_actor, action) do
    not is_nil(Map.get(action, :actor))
  end

  defp passes_predicate?(:require_audit, action) do
    params = Map.get(action, :params, %{})
    not Map.get(params, :skip_audit, false)
  end

  defp passes_predicate?(:require_justification, action) do
    j = Map.get(action, :justification, "")
    is_binary(j) and String.length(j) > 0
  end

  defp passes_predicate?(:no_bulk_delete, action) do
    Map.get(action, :type) != :bulk_delete
  end

  defp passes_predicate?(:require_approval, action) do
    params = Map.get(action, :params, %{})
    Map.get(params, :approved, false) == true
  end

  defp passes_predicate?(_unknown, _action), do: true

  @spec predicate_reason(atom()) :: String.t()
  defp predicate_reason(:require_actor), do: "action must have a non-nil actor"
  defp predicate_reason(:require_audit), do: "skip_audit=true violates auditability norm"
  defp predicate_reason(:require_justification), do: "action lacks required justification"
  defp predicate_reason(:no_bulk_delete), do: "bulk_delete violates destructiveness norm"
  defp predicate_reason(:require_approval), do: "action requires explicit approval"
  defp predicate_reason(p), do: "predicate #{p} failed"

  @spec compute_score([norm()], [violation()]) :: float()
  defp compute_score([], _violations), do: 1.0

  defp compute_score(norms, violations) do
    violated_ids = MapSet.new(violations, & &1.norm_id)
    total_weight = Enum.sum(Enum.map(norms, & &1.weight))

    failed_weight =
      norms
      |> Enum.filter(fn n -> MapSet.member?(violated_ids, n.id) end)
      |> Enum.reduce(0.0, fn n, acc -> acc + n.weight end)

    max(0.0, (total_weight - failed_weight) / total_weight)
  end

  @spec valid_norm?(term()) :: boolean()
  defp valid_norm?(%{id: id, category: cat, predicate: pred, weight: w, severity: sev})
       when is_binary(id) and is_atom(cat) and is_atom(pred) and is_float(w) and is_atom(sev) do
    w >= 0.0 and w <= 1.0 and sev in [:critical, :high, :medium, :low]
  end

  defp valid_norm?(_), do: false
end
