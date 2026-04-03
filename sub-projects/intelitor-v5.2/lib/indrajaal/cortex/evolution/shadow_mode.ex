defmodule Indrajaal.Cortex.Evolution.ShadowMode do
  @moduledoc """
  Shadow Mode Executor: Safe AI Model Evaluation without Actuator Access.

  WHAT: Runs new AI models/logic in isolation, comparing outputs to production.
  WHY: SC-NEURO-004 requires Shadow Mode validation before model promotion.
  CONSTRAINTS: Shadow outputs MUST be disconnected from actuators.

  ## Shadow Mode Execution Flow

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                    SHADOW MODE ARCHITECTURE                      │
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐   │
  │   │  LIVE INPUT                                              │   │
  │   │  (Production telemetry, events, sensor data)             │   │
  │   └────────────────────────┬────────────────────────────────┘   │
  │                            │                                     │
  │              ┌─────────────┴─────────────┐                       │
  │              ▼                           ▼                       │
  │   ┌──────────────────┐        ┌──────────────────┐              │
  │   │  PRODUCTION AI   │        │   SHADOW AI      │              │
  │   │  (Active Model)  │        │   (Candidate)    │              │
  │   └────────┬─────────┘        └────────┬─────────┘              │
  │            │                           │                         │
  │            ▼                           ▼                         │
  │   ┌──────────────────┐        ┌──────────────────┐              │
  │   │  GUARDIAN        │        │   SHADOW LOG     │              │
  │   │  (Actuator Gate) │        │   (No Actuators) │              │
  │   └──────────────────┘        └──────────────────┘              │
  │                                        │                         │
  │                                        ▼                         │
  │                              ┌──────────────────┐                │
  │                              │  COMPARATOR      │                │
  │                              │  (Diff Analysis) │                │
  │                              └──────────────────┘                │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## Promotion Criteria

  A shadow model is promoted to production when:
  1. $N$ cycles (configurable, default 10,000) have been executed
  2. Zero safety violations (Guardian vetoes)
  3. Agreement rate with production >= 95%
  4. Human operator approval (Two-Key Turn)

  ## STAMP Constraints

  | ID | Constraint | Severity |
  |----|------------|----------|
  | SC-SHADOW-001 | Shadow outputs SHALL NOT touch actuators | CRITICAL |
  | SC-SHADOW-002 | All shadow decisions logged for analysis | HIGH |
  | SC-SHADOW-003 | Promotion requires zero violations | CRITICAL |
  | SC-SHADOW-004 | Human approval required for promotion | HIGH |

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-SHADOW-001 to SC-SHADOW-004 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Observability.ZenohNeuralStream
  alias Indrajaal.Observability.ZenohEvolutionPublisher
  alias Indrajaal.Shared.UnifiedGenServerPatterns

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type shadow_model :: %{
          id: String.t(),
          name: String.t(),
          type: :local | :cloud | :custom,
          inference_fn: (map() -> {:ok, map()} | {:error, term()}),
          metadata: map()
        }

  @type shadow_result :: %{
          model_id: String.t(),
          input: map(),
          output: map() | nil,
          would_be_vetoed: boolean(),
          veto_reason: atom() | nil,
          latency_ms: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @type comparison_result :: %{
          production_output: map(),
          shadow_output: map(),
          agreement: boolean(),
          diff: map(),
          analysis: String.t()
        }

  @type promotion_status :: %{
          model_id: String.t(),
          cycles: non_neg_integer(),
          violations: non_neg_integer(),
          agreement_rate: float(),
          ready_for_promotion: boolean(),
          blocking_reasons: [String.t()]
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_promotion_threshold 10_000
  @min_agreement_rate 0.95

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a shadow model for evaluation.

  ## Parameters
  - model: Shadow model specification

  ## Returns
  - {:ok, model_id} on success
  - {:error, reason} on failure
  """
  @spec register_shadow(shadow_model()) :: {:ok, String.t()} | {:error, term()}
  def register_shadow(model) do
    GenServer.call(__MODULE__, {:register, model})
  end

  @doc """
  Unregisters a shadow model.
  """
  @spec unregister_shadow(String.t()) :: :ok | {:error, :not_found}
  def unregister_shadow(model_id) do
    GenServer.call(__MODULE__, {:unregister, model_id})
  end

  @doc """
  Executes a shadow model with given input.
  The output is logged but NOT sent to actuators.

  ## Parameters
  - model_id: The registered shadow model ID
  - input: Input data for the model

  ## Returns
  - {:ok, shadow_result} with model output (not executed)
  - {:error, reason} if model not found or execution fails
  """
  @spec execute_shadow(String.t(), map()) :: {:ok, shadow_result()} | {:error, term()}
  def execute_shadow(model_id, input) do
    GenServer.call(__MODULE__, {:execute, model_id, input}, 30_000)
  end

  @doc """
  Runs both production and shadow models, comparing outputs.

  ## Parameters
  - model_id: Shadow model to compare
  - input: Input data
  - production_fn: Production model function

  ## Returns
  - {:ok, comparison_result}
  """
  @spec compare_with_production(String.t(), map(), (map() -> {:ok, map()})) ::
          {:ok, comparison_result()} | {:error, term()}
  def compare_with_production(model_id, input, production_fn) do
    GenServer.call(__MODULE__, {:compare, model_id, input, production_fn}, 60_000)
  end

  @doc """
  Gets promotion status for a shadow model.
  """
  @spec promotion_status(String.t()) :: {:ok, promotion_status()} | {:error, :not_found}
  def promotion_status(model_id) do
    GenServer.call(__MODULE__, {:promotion_status, model_id})
  end

  @doc """
  Attempts to promote a shadow model to production.
  Requires all criteria to be met and returns a promotion token for Two-Key Turn.

  ## Returns
  - {:ok, promotion_token} if criteria met
  - {:error, :not_ready, reasons} if criteria not met
  """
  @spec request_promotion(String.t()) :: {:ok, String.t()} | {:error, :not_ready, [String.t()]}
  def request_promotion(model_id) do
    GenServer.call(__MODULE__, {:request_promotion, model_id})
  end

  @doc """
  Confirms promotion with second key (Two-Key Turn).
  """
  @spec confirm_promotion(String.t(), String.t()) :: {:ok, :promoted} | {:error, term()}
  def confirm_promotion(promotion_token, confirmation_code) do
    GenServer.call(__MODULE__, {:confirm_promotion, promotion_token, confirmation_code})
  end

  @doc """
  Gets all registered shadow models.
  """
  @spec list_shadows() :: [map()]
  def list_shadows do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Gets shadow mode statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    promotion_threshold = Keyword.get(opts, :promotion_threshold, @default_promotion_threshold)

    Logger.info("[ShadowMode] Initializing shadow mode executor - SC-SHADOW-001")

    state = %{
      # Registered shadow models
      models: %{},
      # Execution history per model
      history: %{},
      # Pending promotions
      pending_promotions: %{},
      # Configuration
      promotion_threshold: promotion_threshold,
      min_agreement_rate: @min_agreement_rate,
      # Statistics
      total_executions: 0,
      total_violations: 0,
      total_agreements: 0,
      total_disagreements: 0,
      # Started timestamp
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, model}, _from, state) do
    # SC-SHADOW-001: Validate required fields for model registration
    with :ok <- validate_required_fields(model) do
      model_id = model[:id] || generate_model_id()

      validated_model = %{
        id: model_id,
        name: model[:name] || "Shadow Model #{model_id}",
        type: model[:type] || :custom,
        inference_fn: model[:inference_fn],
        metadata: model[:metadata] || %{},
        registered_at: DateTime.utc_now()
      }

      new_models = Map.put(state.models, model_id, validated_model)

      new_history =
        Map.put(state.history, model_id, %{
          cycles: 0,
          violations: 0,
          agreements: 0,
          disagreements: 0,
          results: []
        })

      Logger.info("[ShadowMode] Registered shadow model: #{model_id}")

      {:reply, {:ok, model_id}, %{state | models: new_models, history: new_history}}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unregister, model_id}, _from, state) do
    if Map.has_key?(state.models, model_id) do
      new_models = Map.delete(state.models, model_id)
      new_history = Map.delete(state.history, model_id)
      Logger.info("[ShadowMode] Unregistered shadow model: #{model_id}")
      {:reply, :ok, %{state | models: new_models, history: new_history}}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:execute, model_id, input}, _from, state) do
    case Map.get(state.models, model_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      model ->
        {result, new_state} = execute_shadow_model(model, input, state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:compare, model_id, input, production_fn}, _from, state) do
    case Map.get(state.models, model_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      model ->
        {result, new_state} = compare_models(model, input, production_fn, state)
        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:promotion_status, model_id}, _from, state) do
    case Map.get(state.history, model_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      history ->
        status = calculate_promotion_status(model_id, history, state)
        {:reply, {:ok, status}, state}
    end
  end

  @impl true
  def handle_call({:request_promotion, model_id}, _from, state) do
    case Map.get(state.history, model_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      history ->
        status = calculate_promotion_status(model_id, history, state)

        if status.ready_for_promotion do
          token = generate_promotion_token()

          pending = %{
            model_id: model_id,
            token: token,
            confirmation_code: generate_confirmation_code(),
            requested_at: DateTime.utc_now(),
            expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
          }

          new_pending = Map.put(state.pending_promotions, token, pending)

          Logger.info("[ShadowMode] Promotion requested for #{model_id}: #{token}")

          {:reply, {:ok, token}, %{state | pending_promotions: new_pending}}
        else
          {:reply, {:error, :not_ready, status.blocking_reasons}, state}
        end
    end
  end

  @impl true
  def handle_call({:confirm_promotion, token, confirmation_code}, _from, state) do
    pending = Map.get(state.pending_promotions, token)

    case UnifiedGenServerPatterns.validate_two_key_confirmation(
           pending,
           confirmation_code,
           not_found_error: :invalid_token
         ) do
      {:ok, :confirmed} ->
        # Promotion confirmed!
        new_pending = Map.delete(state.pending_promotions, token)

        Logger.info(
          "[ShadowMode] Model #{pending.model_id} PROMOTED to production via Two-Key Turn"
        )

        stream_event(:promotion, pending.model_id, %{token: token})

        {:reply, {:ok, :promoted}, %{state | pending_promotions: new_pending}}

      {:error, :expired} ->
        new_pending = Map.delete(state.pending_promotions, token)
        {:reply, {:error, :expired}, %{state | pending_promotions: new_pending}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    models =
      Enum.map(state.models, fn {id, model} ->
        history = Map.get(state.history, id, %{})

        %{
          id: id,
          name: model.name,
          type: model.type,
          cycles: Map.get(history, :cycles, 0),
          violations: Map.get(history, :violations, 0),
          registered_at: model.registered_at
        }
      end)

    {:reply, models, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    agreement_rate =
      total = state.total_agreements + state.total_disagreements

    if total > 0,
      do: Float.round(state.total_agreements / total * 100, 2),
      else: 0.0

    stats = %{
      registered_models: map_size(state.models),
      total_executions: state.total_executions,
      total_violations: state.total_violations,
      total_agreements: state.total_agreements,
      total_disagreements: state.total_disagreements,
      agreement_rate: agreement_rate,
      pending_promotions: map_size(state.pending_promotions),
      promotion_threshold: state.promotion_threshold,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  # ============================================================
  # PRIVATE - VALIDATION
  # ============================================================

  defp validate_required_fields(model) do
    cond do
      # Must have either model_id + inference details OR inference_fn
      is_nil(model[:inference_fn]) and is_nil(model[:model_type]) and is_nil(model[:type]) ->
        {:error, :invalid_config}

      # If inference_fn is nil, must have model_type for internal models
      is_nil(model[:inference_fn]) and model[:type] == :custom ->
        {:error, :invalid_config}

      true ->
        :ok
    end
  end

  # ============================================================
  # PRIVATE - EXECUTION
  # ============================================================

  defp execute_shadow_model(model, input, state) do
    start_time = System.monotonic_time(:millisecond)

    # Execute the shadow model's inference function
    output_result =
      try do
        model.inference_fn.(input)
      rescue
        e -> {:error, {:exception, Exception.message(e)}}
      end

    latency_ms = System.monotonic_time(:millisecond) - start_time

    # Check what Guardian would do (but don't actually execute)
    {would_be_vetoed, veto_reason} =
      case output_result do
        {:ok, output} ->
          case Guardian.validate_proposal(output) do
            {:ok, _} -> {false, nil}
            {:veto, reason, _} -> {true, reason}
          end

        {:error, _} ->
          {false, nil}
      end

    result = %{
      model_id: model.id,
      input: input,
      output: if(match?({:ok, _}, output_result), do: elem(output_result, 1), else: nil),
      would_be_vetoed: would_be_vetoed,
      veto_reason: veto_reason,
      latency_ms: latency_ms,
      timestamp: DateTime.utc_now()
    }

    # Update history
    history = Map.get(state.history, model.id, %{cycles: 0, violations: 0, results: []})

    new_history = %{
      history
      | cycles: history.cycles + 1,
        violations: history.violations + if(would_be_vetoed, do: 1, else: 0),
        results: [result | Enum.take(history.results, 99)]
    }

    new_state = %{
      state
      | history: Map.put(state.history, model.id, new_history),
        total_executions: state.total_executions + 1,
        total_violations: state.total_violations + if(would_be_vetoed, do: 1, else: 0)
    }

    # Stream telemetry (but NOT actuator commands!)
    stream_shadow_result(result)

    {{:ok, result}, new_state}
  end

  defp compare_models(model, input, production_fn, state) do
    # Execute production model
    production_result = production_fn.(input)

    production_output =
      case production_result do
        {:ok, output} -> output
        _ -> %{}
      end

    # Execute shadow model
    {{:ok, shadow_result}, intermediate_state} = execute_shadow_model(model, input, state)

    shadow_output = shadow_result.output || %{}

    # Compare outputs
    agreement = outputs_agree?(production_output, shadow_output)

    diff = compute_diff(production_output, shadow_output)

    analysis =
      cond do
        agreement -> "Outputs match - shadow model agrees with production"
        shadow_result.would_be_vetoed -> "Shadow output would be VETOED by Guardian"
        true -> "Outputs differ - review required"
      end

    comparison = %{
      production_output: production_output,
      shadow_output: shadow_output,
      agreement: agreement,
      diff: diff,
      analysis: analysis
    }

    # Update agreement stats
    history = Map.get(intermediate_state.history, model.id, %{agreements: 0, disagreements: 0})

    new_history =
      if agreement do
        %{history | agreements: Map.get(history, :agreements, 0) + 1}
      else
        %{history | disagreements: Map.get(history, :disagreements, 0) + 1}
      end

    {total_agreements, total_disagreements} =
      if agreement do
        {intermediate_state.total_agreements + 1, intermediate_state.total_disagreements}
      else
        {intermediate_state.total_agreements, intermediate_state.total_disagreements + 1}
      end

    new_state = %{
      intermediate_state
      | history: Map.put(intermediate_state.history, model.id, new_history),
        total_agreements: total_agreements,
        total_disagreements: total_disagreements
    }

    # SC-ZENOH-EVO-001: Publish comparison to Zenoh
    stream_comparison(model.id, comparison)

    {{:ok, comparison}, new_state}
  end

  defp outputs_agree?(prod, shadow) when is_map(prod) and is_map(shadow) do
    # Compare action types - the key decision
    Map.get(prod, :action) == Map.get(shadow, :action)
  end

  defp outputs_agree?(prod, shadow), do: prod == shadow

  defp compute_diff(prod, shadow) when is_map(prod) and is_map(shadow) do
    all_keys = MapSet.union(MapSet.new(Map.keys(prod)), MapSet.new(Map.keys(shadow)))

    Enum.reduce(all_keys, %{}, fn key, acc ->
      prod_val = Map.get(prod, key)
      shadow_val = Map.get(shadow, key)

      if prod_val != shadow_val do
        Map.put(acc, key, %{production: prod_val, shadow: shadow_val})
      else
        acc
      end
    end)
  end

  defp compute_diff(prod, shadow), do: %{production: prod, shadow: shadow}

  # ============================================================
  # PRIVATE - PROMOTION
  # ============================================================

  defp calculate_promotion_status(model_id, history, state) do
    cycles = Map.get(history, :cycles, 0)
    violations = Map.get(history, :violations, 0)
    agreements = Map.get(history, :agreements, 0)
    disagreements = Map.get(history, :disagreements, 0)

    total_comparisons = agreements + disagreements

    agreement_rate =
      if total_comparisons > 0,
        do: agreements / total_comparisons,
        else: 0.0

    # Determine blocking reasons
    blocking_reasons = []

    blocking_reasons =
      if cycles < state.promotion_threshold do
        ["Insufficient cycles: #{cycles}/#{state.promotion_threshold}" | blocking_reasons]
      else
        blocking_reasons
      end

    blocking_reasons =
      if violations > 0 do
        ["#{violations} safety violations detected" | blocking_reasons]
      else
        blocking_reasons
      end

    blocking_reasons =
      if agreement_rate < state.min_agreement_rate and total_comparisons > 0 do
        [
          "Agreement rate #{Float.round(agreement_rate * 100, 1)}% < #{state.min_agreement_rate * 100}%"
          | blocking_reasons
        ]
      else
        blocking_reasons
      end

    %{
      model_id: model_id,
      cycles: cycles,
      violations: violations,
      agreement_rate: Float.round(agreement_rate * 100, 2),
      ready_for_promotion: Enum.empty?(blocking_reasons),
      blocking_reasons: blocking_reasons
    }
  end

  # ============================================================
  # PRIVATE - HELPERS
  # ============================================================

  defp generate_model_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    encoded = rand_bytes |> Base.encode16(case: :lower)
    "shadow_#{encoded}"
  end

  defp generate_promotion_token do
    rand_bytes = :crypto.strong_rand_bytes(16)
    encoded = rand_bytes |> Base.encode16(case: :lower)
    "promo_#{encoded}"
  end

  defp generate_confirmation_code do
    rand_bytes = :crypto.strong_rand_bytes(4)
    rand_bytes |> Base.encode16(case: :upper)
  end

  defp stream_shadow_result(result) do
    # SC-ZENOH-EVO-001: Publish to ZenohEvolutionPublisher
    if Code.ensure_loaded?(ZenohEvolutionPublisher) and
         GenServer.whereis(ZenohEvolutionPublisher) do
      ZenohEvolutionPublisher.publish_shadow_execution(result.model_id, %{
        would_be_vetoed: result.would_be_vetoed,
        veto_reason: result.veto_reason,
        latency_ms: result.latency_ms,
        timestamp: result.timestamp
      })
    end

    # Also stream to ZenohNeuralStream for legacy compatibility
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:shadow_mode, :execution, %{
        model_id: result.model_id,
        would_be_vetoed: result.would_be_vetoed,
        veto_reason: result.veto_reason,
        latency_ms: result.latency_ms,
        timestamp: result.timestamp
      })
    end
  rescue
    _ -> :ok
  end

  defp stream_comparison(model_id, comparison) do
    # SC-ZENOH-EVO-001: Publish comparison to ZenohEvolutionPublisher
    if Code.ensure_loaded?(ZenohEvolutionPublisher) and
         GenServer.whereis(ZenohEvolutionPublisher) do
      ZenohEvolutionPublisher.publish_shadow_comparison(model_id, %{
        agreement: comparison.agreement,
        diff_keys: Map.keys(comparison.diff),
        analysis: comparison.analysis
      })
    end
  rescue
    _ -> :ok
  end

  defp stream_event(type, model_id, data) do
    # SC-ZENOH-EVO-001: Publish promotion events to ZenohEvolutionPublisher
    if type == :promotion and Code.ensure_loaded?(ZenohEvolutionPublisher) and
         GenServer.whereis(ZenohEvolutionPublisher) do
      ZenohEvolutionPublisher.publish_shadow_promotion(model_id, data)
    end

    # Also stream to ZenohNeuralStream
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:shadow_mode, type, Map.put(data, :model_id, model_id))
    end
  rescue
    _ -> :ok
  end
end
