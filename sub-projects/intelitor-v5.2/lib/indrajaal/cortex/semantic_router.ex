defmodule Indrajaal.Cortex.SemanticRouter do
  @moduledoc """
  Cortex Semantic Router — Intent-Based Message Routing for Cognitive Operations.

  ## WHAT
  Routes cognitive operations (AI inference requests, knowledge queries,
  evolution proposals) to the appropriate Cortex subsystem based on semantic
  classification of the message intent. This is the Cortex's "thalamus" —
  filtering and directing information flows to specialized processors.

  ## WHY
  The Cortex has multiple specialized subsystems (Synapse for AI, GDE for
  evolution, SelfHealing for remediation, Predictor for forecasting). Without
  semantic routing, callers must know the internal topology. The SemanticRouter
  provides a single entry point that classifies intent and dispatches to the
  correct handler, enabling loose coupling.

  ## IMPORTANT
  This module is DISTINCT from `Indrajaal.Observability.Zenoh.SemanticRouter`
  which handles Zenoh topic routing for telemetry. This module operates at the
  Cortex cognitive layer for AI/reasoning operations.

  ## CONSTRAINTS
  - SC-CTX-001: All cognitive components must be supervised
  - SC-NEURO-001: AI output MUST pass Guardian validation
  - SC-PRF-055: No blocking operations

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-24 |
  | Author | Cybernetic Architect |
  | STAMP | SC-CTX-001, SC-NEURO-001, SC-PRF-055 |
  """

  use GenServer
  require Logger

  @route_timeout_ms 5_000

  # ── Route Definitions ───────────────────────────────────────────────

  @intent_patterns %{
    inference: {Indrajaal.Cortex.Synapse, :think},
    evolution: {Indrajaal.Cortex.GDE.Controller, :propose},
    healing: {Indrajaal.Cortex.SelfHealing, :report_failure},
    prediction: {Indrajaal.Cortex.Predictor, :predict},
    knowledge: {Indrajaal.Cortex.Synapse, :think},
    analysis: {Indrajaal.Cortex.Synapse, :think}
  }

  @intent_keywords %{
    inference: ~w(infer predict classify generate complete chat ask),
    evolution: ~w(evolve mutate adapt optimize improve refactor),
    healing: ~w(heal fix repair recover restore remediate restart),
    prediction: ~w(forecast trend predict anticipate project),
    knowledge: ~w(search find query lookup retrieve knowledge),
    analysis: ~w(analyze audit inspect verify validate check)
  }

  # ── Public API ──────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Routes a message to the appropriate Cortex subsystem based on intent.

  ## Parameters
  - `message` — The message to route (string or map)
  - `opts` — Options including `:intent` (explicit override), `:timeout`

  ## Returns
  - `{:ok, result}` — Successfully routed and processed
  - `{:error, :unknown_intent}` — Could not classify the message
  - `{:error, :handler_unavailable}` — Target subsystem not running
  """
  @spec route(String.t() | map(), keyword()) :: {:ok, term()} | {:error, atom()}
  def route(message, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:route, message, opts},
      Keyword.get(opts, :timeout, @route_timeout_ms)
    )
  end

  @doc """
  Classifies the intent of a message without routing it.

  ## Returns
  - `{:ok, intent_atom}` — Classified intent
  - `{:error, :unknown_intent}` — Could not classify
  """
  @spec classify(String.t() | map()) :: {:ok, atom()} | {:error, :unknown_intent}
  def classify(message) do
    GenServer.call(__MODULE__, {:classify, message})
  end

  @doc """
  Returns routing statistics.
  """
  @spec stats() :: {:ok, map()}
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    state = %{
      route_count: 0,
      route_stats: %{},
      last_route: nil,
      errors: 0
    }

    :telemetry.execute(
      [:indrajaal, :cortex, :semantic_router, :started],
      %{intent_count: map_size(@intent_patterns)},
      %{}
    )

    Logger.info(
      "[SemanticRouter] Started — #{map_size(@intent_patterns)} intent patterns registered"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:route, message, opts}, _from, state) do
    # Allow explicit intent override
    intent_result =
      case Keyword.get(opts, :intent) do
        nil -> classify_intent(message)
        explicit -> {:ok, explicit}
      end

    case intent_result do
      {:ok, intent} ->
        result = dispatch(intent, message, opts)
        stats = Map.update(state.route_stats, intent, 1, &(&1 + 1))

        :telemetry.execute(
          [:indrajaal, :cortex, :semantic_router, :routed],
          %{intent: intent},
          %{route_count: state.route_count + 1}
        )

        new_state = %{
          state
          | route_count: state.route_count + 1,
            route_stats: stats,
            last_route: {intent, DateTime.utc_now()}
        }

        {:reply, result, new_state}

      {:error, :unknown_intent} = err ->
        Logger.warning("[SemanticRouter] Unknown intent for message: #{inspect_message(message)}")

        :telemetry.execute(
          [:indrajaal, :cortex, :semantic_router, :unknown_intent],
          %{},
          %{message: inspect_message(message)}
        )

        {:reply, err, %{state | errors: state.errors + 1}}
    end
  end

  def handle_call({:classify, message}, _from, state) do
    result = classify_intent(message)
    {:reply, result, state}
  end

  def handle_call(:stats, _from, state) do
    {:reply, {:ok, Map.take(state, [:route_count, :route_stats, :last_route, :errors])}, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Intent Classification ───────────────────────────────────────────

  defp classify_intent(message) when is_binary(message) do
    downcased = String.downcase(message)
    words = String.split(downcased, ~r/[\s,.:;!?]+/, trim: true)

    # Score each intent by keyword matches
    scores =
      @intent_keywords
      |> Enum.map(fn {intent, keywords} ->
        score = Enum.count(words, fn word -> word in keywords end)
        {intent, score}
      end)
      |> Enum.filter(fn {_intent, score} -> score > 0 end)
      |> Enum.sort_by(fn {_intent, score} -> score end, :desc)

    case scores do
      [{intent, _score} | _] -> {:ok, intent}
      [] -> {:error, :unknown_intent}
    end
  end

  defp classify_intent(%{intent: intent}) when is_atom(intent), do: {:ok, intent}

  defp classify_intent(%{"intent" => intent}) when is_binary(intent),
    do: {:ok, String.to_existing_atom(intent)}

  defp classify_intent(%{message: message}) when is_binary(message), do: classify_intent(message)

  defp classify_intent(%{"message" => message}) when is_binary(message),
    do: classify_intent(message)

  defp classify_intent(_), do: {:error, :unknown_intent}

  # ── Dispatch ────────────────────────────────────────────────────────

  defp dispatch(intent, message, _opts) do
    case Map.get(@intent_patterns, intent) do
      {module, function} ->
        if process_alive?(module) do
          try do
            apply(module, function, [normalize_message(message)])
          rescue
            e ->
              Logger.error(
                "[SemanticRouter] Dispatch failed for #{intent}: #{Exception.message(e)}"
              )

              {:error, :dispatch_failed}
          end
        else
          {:error, :handler_unavailable}
        end

      nil ->
        {:error, :unknown_intent}
    end
  end

  defp process_alive?(module) do
    case Process.whereis(module) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  defp normalize_message(message) when is_binary(message), do: message
  defp normalize_message(%{message: msg}), do: msg
  defp normalize_message(%{"message" => msg}), do: msg
  defp normalize_message(message), do: inspect(message)

  defp inspect_message(message) when is_binary(message), do: String.slice(message, 0, 100)
  defp inspect_message(message), do: inspect(message, limit: 3)
end
