defmodule Indrajaal.Cortex.GDE.ShadowTestFramework do
  @moduledoc """
  WHAT: GDE-specific proposal validation pipeline using shadow testing.
  WHY: Validates Goal-Directed Evolution proposals in an isolated shadow
       environment before Guardian approval, catching regressions without
       impacting production behaviour.
  CONSTRAINTS: SC-GDE-001 (Guardian validation required), SC-GDE-002 (shadow testing mandatory),
               SC-GDE-003 (rollback capability), SC-GDE-004 (proposal threshold >= 0.85),
               SC-SHADOW-001 to SC-SHADOW-004 (shadow mode isolation),
               SC-NEURO-001 (simplex principle — AI output passes Guardian),
               AOR-GDE-001 (generators for candidate exploration),
               AOR-GDE-002 (all proposals pass Guardian),
               AOR-REG-005 (shadow testing before activation).

  ## Architecture

  ```
  ProposalEngine
      │
      ▼
  ShadowTestFramework     ◄─── this module (Cortex/GDE L3)
      │
      ├─ Phase 1: Schema validation (structure + STAMP refs)
      ├─ Phase 2: Functional shadow (isolated execution)
      ├─ Phase 3: Fitness scoring (correctness × coverage × quality × STAMP)
      ├─ Phase 4: Regression diff (compare with baseline)
      └─ Phase 5: Guardian gate (threshold >= 0.85)
  ```

  ## Fitness Formula (SC-GDE-004)

  ```
  F(Δ) = w_c·C + w_t·T + w_q·Q + w_s·S
  where:
    C = correctness (tests pass / total)
    T = test coverage ratio
    Q = quality gate score (0 compile errors/warnings)
    S = STAMP compliance score
    weights: w_c=0.4, w_t=0.3, w_q=0.2, w_s=0.1
  ```
  """

  require Logger

  alias Indrajaal.Cortex.Evolution.ShadowMode

  @type proposal :: %{
          id: String.t(),
          type: atom(),
          module: atom() | String.t(),
          changes: [map()],
          stamp_refs: [String.t()],
          author: String.t()
        }

  @type validation_result :: %{
          proposal_id: String.t(),
          phase: :schema | :shadow | :fitness | :regression | :guardian,
          passed: boolean(),
          fitness: float(),
          errors: [String.t()],
          warnings: [String.t()],
          duration_ms: non_neg_integer()
        }

  # Fitness thresholds (SC-GDE-004)
  @fitness_threshold 0.85
  @weights %{correctness: 0.4, coverage: 0.3, quality: 0.2, stamp: 0.1}

  @doc """
  Runs the full 5-phase validation pipeline for a GDE proposal.

  Returns `{:ok, result}` if fitness >= 0.85, or `{:error, result}` otherwise.

  ## Parameters
  - `proposal` — the GDE proposal map
  - `opts` — keyword options: `timeout_ms`, `baseline_snapshot`

  ## Examples

      iex> ShadowTestFramework.validate(proposal)
      {:ok, %{passed: true, fitness: 0.92, ...}}

      iex> ShadowTestFramework.validate(bad_proposal)
      {:error, %{passed: false, fitness: 0.41, errors: ["STAMP ref missing"], ...}}
  """
  @spec validate(proposal(), keyword()) ::
          {:ok, validation_result()} | {:error, validation_result()}
  def validate(proposal, opts \\ []) do
    start_ts = System.monotonic_time(:millisecond)
    timeout_ms = Keyword.get(opts, :timeout_ms, 30_000)
    # Safely extract proposal_id — :id may be absent if schema is invalid
    proposal_id = Map.get(proposal, :id, "unknown")

    result =
      with {:ok, _} <- phase_schema(proposal),
           {:ok, shadow_result} <- phase_shadow(proposal, timeout_ms),
           {:ok, fitness} <- phase_fitness(proposal, shadow_result),
           {:ok, _} <- phase_regression(proposal, shadow_result, opts),
           {:ok, _} <- phase_guardian_gate(fitness) do
        {:ok, build_result(proposal_id, :guardian, true, fitness, [], [], start_ts)}
      else
        {:error, phase, errors} ->
          fitness = 0.0
          result = build_result(proposal_id, phase, false, fitness, errors, [], start_ts)
          {:error, result}
      end

    log_validation_result(result)
    result
  end

  @doc """
  Runs only the schema validation phase (Phase 1).

  Checks required fields, STAMP refs, and change list structure.
  """
  @spec validate_schema(proposal()) :: {:ok, :schema_valid} | {:error, :schema, [String.t()]}
  def validate_schema(proposal), do: phase_schema(proposal)

  @doc """
  Computes fitness score for a proposal given shadow execution results.

  Uses the weighted formula: F = w_c·C + w_t·T + w_q·Q + w_s·S

  ## Parameters
  - `proposal` — the GDE proposal
  - `shadow_result` — result map from shadow execution

  ## Returns
  - `{:ok, fitness}` where fitness is 0.0–1.0
  """
  @spec compute_fitness(proposal(), map()) :: {:ok, float()} | {:error, :fitness, [String.t()]}
  def compute_fitness(proposal, shadow_result), do: phase_fitness(proposal, shadow_result)

  @doc """
  Returns the current fitness threshold required for Guardian approval.
  """
  @spec fitness_threshold() :: float()
  def fitness_threshold, do: @fitness_threshold

  # ---- Phases ----

  @spec phase_schema(proposal()) :: {:ok, :schema_valid} | {:error, :schema, [String.t()]}
  defp phase_schema(proposal) do
    errors =
      []
      |> check_required_field(proposal, :id)
      |> check_required_field(proposal, :type)
      |> check_required_field(proposal, :module)
      |> check_required_field(proposal, :changes)
      |> check_required_field(proposal, :stamp_refs)
      |> check_stamp_refs(proposal)
      |> check_changes_list(proposal)

    if errors == [] do
      {:ok, :schema_valid}
    else
      {:error, :schema, errors}
    end
  end

  @spec phase_shadow(proposal(), pos_integer()) ::
          {:ok, map()} | {:error, :shadow, [String.t()]}
  defp phase_shadow(proposal, timeout_ms) do
    # Register as shadow model and execute
    shadow_config = %{
      id: "gde_shadow_#{proposal.id}",
      module: proposal.module,
      type: :gde_proposal,
      changes: proposal.changes
    }

    # Wrap in try/catch to handle EXIT when ShadowMode is not running (SC-GDE-002)
    try do
      case ShadowMode.register_shadow(shadow_config) do
        {:ok, shadow_id} ->
          case ShadowMode.execute_shadow(shadow_id, %{timeout_ms: timeout_ms}) do
            {:ok, result} ->
              ShadowMode.unregister_shadow(shadow_id)
              {:ok, result}

            {:error, reason} ->
              ShadowMode.unregister_shadow(shadow_id)
              {:error, :shadow, ["Shadow execution failed: #{inspect(reason)}"]}
          end

        {:error, reason} ->
          {:error, :shadow, ["Shadow registration failed: #{inspect(reason)}"]}
      end
    catch
      :exit, reason ->
        {:error, :shadow, ["ShadowMode unavailable: #{inspect(reason)}"]}
    end
  end

  @spec phase_fitness(proposal(), map()) :: {:ok, float()} | {:error, :fitness, [String.t()]}
  defp phase_fitness(proposal, shadow_result) do
    correctness = Map.get(shadow_result, :tests_passed_ratio, 1.0)
    coverage = Map.get(shadow_result, :coverage_ratio, 0.8)
    quality = Map.get(shadow_result, :quality_score, 0.9)
    stamp = compute_stamp_score(proposal.stamp_refs)

    fitness =
      @weights.correctness * correctness +
        @weights.coverage * coverage +
        @weights.quality * quality +
        @weights.stamp * stamp

    rounded = Float.round(fitness, 4)

    if rounded > 1.0 do
      {:error, :fitness, ["Fitness overflow: #{rounded}"]}
    else
      {:ok, rounded}
    end
  end

  @spec phase_regression(proposal(), map(), keyword()) ::
          {:ok, :no_regressions} | {:error, :regression, [String.t()]}
  defp phase_regression(proposal, shadow_result, opts) do
    baseline = Keyword.get(opts, :baseline_snapshot, %{})

    regressions =
      detect_regressions(
        shadow_result,
        baseline,
        proposal.type
      )

    if regressions == [] do
      {:ok, :no_regressions}
    else
      {:error, :regression, regressions}
    end
  end

  @spec phase_guardian_gate(float()) ::
          {:ok, :approved} | {:error, :guardian, [String.t()]}
  defp phase_guardian_gate(fitness) do
    if fitness >= @fitness_threshold do
      {:ok, :approved}
    else
      {:error, :guardian,
       [
         "Fitness #{Float.round(fitness, 3)} below threshold #{@fitness_threshold} (SC-GDE-004)"
       ]}
    end
  end

  # ---- Helpers ----

  @spec check_required_field([String.t()], proposal(), atom()) :: [String.t()]
  defp check_required_field(errors, proposal, field) do
    if Map.get(proposal, field) in [nil, "", []] do
      ["Required field :#{field} is missing or empty" | errors]
    else
      errors
    end
  end

  @spec check_stamp_refs([String.t()], proposal()) :: [String.t()]
  defp check_stamp_refs(errors, %{stamp_refs: refs}) when is_list(refs) do
    invalid = Enum.filter(refs, fn ref -> not (ref =~ ~r/^(SC|AOR)-[A-Z0-9]+-\d+$/) end)

    if invalid == [] do
      errors
    else
      ["Invalid STAMP refs: #{Enum.join(invalid, ", ")}" | errors]
    end
  end

  defp check_stamp_refs(errors, _), do: ["stamp_refs must be a list" | errors]

  @spec check_changes_list([String.t()], proposal()) :: [String.t()]
  defp check_changes_list(errors, %{changes: changes}) when is_list(changes) and changes != [] do
    errors
  end

  defp check_changes_list(errors, _), do: ["changes must be a non-empty list" | errors]

  @spec compute_stamp_score([String.t()]) :: float()
  defp compute_stamp_score(stamp_refs) when is_list(stamp_refs) and length(stamp_refs) > 0 do
    # Score based on having at least one GDE ref and reasonable total count
    has_gde_ref = Enum.any?(stamp_refs, &(&1 =~ ~r/^SC-GDE-/))
    count_bonus = min(1.0, length(stamp_refs) / 5.0)
    base = if has_gde_ref, do: 0.7, else: 0.4
    Float.round(min(1.0, base + count_bonus * 0.3), 4)
  end

  defp compute_stamp_score(_), do: 0.0

  @spec detect_regressions(map(), map(), atom()) :: [String.t()]
  defp detect_regressions(shadow_result, baseline, _type) when map_size(baseline) == 0 do
    # No baseline → check absolute thresholds
    tests_ratio = Map.get(shadow_result, :tests_passed_ratio, 1.0)

    if tests_ratio < 0.95 do
      ["Test pass ratio #{Float.round(tests_ratio, 3)} below 0.95 minimum"]
    else
      []
    end
  end

  defp detect_regressions(shadow_result, baseline, _type) do
    # Compare against baseline values
    shadow_tests = Map.get(shadow_result, :tests_passed_ratio, 1.0)
    baseline_tests = Map.get(baseline, :tests_passed_ratio, 1.0)

    if shadow_tests < baseline_tests - 0.05 do
      [
        "Test regression: #{Float.round(shadow_tests, 3)} vs baseline #{Float.round(baseline_tests, 3)}"
      ]
    else
      []
    end
  end

  @spec build_result(
          String.t(),
          atom(),
          boolean(),
          float(),
          [String.t()],
          [String.t()],
          integer()
        ) ::
          validation_result()
  defp build_result(proposal_id, phase, passed, fitness, errors, warnings, start_ts) do
    %{
      proposal_id: proposal_id,
      phase: phase,
      passed: passed,
      fitness: fitness,
      errors: errors,
      warnings: warnings,
      duration_ms: System.monotonic_time(:millisecond) - start_ts
    }
  end

  @spec log_validation_result({:ok | :error, validation_result()}) :: :ok
  defp log_validation_result({:ok, result}) do
    Logger.info(
      "[GDE.ShadowTestFramework] proposal=#{result.proposal_id} PASSED " <>
        "fitness=#{result.fitness} duration_ms=#{result.duration_ms}"
    )
  end

  defp log_validation_result({:error, result}) do
    Logger.warning(
      "[GDE.ShadowTestFramework] proposal=#{result.proposal_id} FAILED " <>
        "phase=#{result.phase} fitness=#{result.fitness} " <>
        "errors=#{inspect(result.errors)}"
    )
  end
end
