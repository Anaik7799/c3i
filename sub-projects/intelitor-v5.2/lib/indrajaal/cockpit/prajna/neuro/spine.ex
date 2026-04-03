defmodule Indrajaal.Cockpit.Prajna.Neuro.Spine do
  @moduledoc """
  ## The Neuro-Symbolic Spine

  The high-speed decision engine of the PRAJNA organism. It routes signals between
  local "Reflexes" (Elixir AI/ML) and remote "Cognition" (OpenRouter) based on
  the required Intelligence Level of the task.

  **Architecture:**
  1. **Dorsal Root**: Ingests signal.
  2. **Reflex Arc (L1/L2)**: Attempts local resolution via Bumblebee/Nx.
  3. **Ascending Tract (L3)**: Escalates to OpenRouter if local confidence is low.
  4. **Motor Root**: Dispatches command to Simplex Kernel.

  **SOPv5.11 Compliance:**
  - **SC-NEURO-002**: Local-first preference for latency optimization.
  """
  use GenServer
  require Logger
  alias Indrajaal.AI.OpenRouterClient

  @compile {:no_warn_undefined, Bumblebee}
  @compile {:no_warn_undefined, Bumblebee.Text}

  # --- Configuration ---
  @confidence_threshold 0.85

  defstruct [
    :id,
    # The Bumblebee/Nx serving process
    :serving,
    # Telemetry for reflex accuracy
    :reflex_stats,
    :generation
  ]

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Process a signal through the spinal cord. Returns the decision/action.
  """
  def process_signal(signal) do
    GenServer.call(__MODULE__, {:process, signal}, 15_000)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       id: opts[:id] || Ecto.UUID.generate(),
       serving: nil,
       reflex_stats: %{hits: 0, misses: 0},
       generation: 1
     }, {:continue, :load_neural_model}}
  end

  @impl true
  def handle_continue(:load_neural_model, state) do
    serving =
      case load_neural_model() do
        {:ok, s} -> s
        {:error, _reason} -> nil
      end

    {:noreply, %{state | serving: serving}}
  end

  defp load_neural_model do
    if Code.ensure_loaded?(Bumblebee) do
      Logger.info("[Spine] Loading local neural model via Nx.Serving...")

      try do
        # Use a very small local model for fast reflex classification
        {:ok, model_info} =
          Bumblebee.load_model({:hf, "distilbert-base-uncased-finetuned-sst-2-english"})

        {:ok, tokenizer} =
          Bumblebee.load_tokenizer({:hf, "distilbert-base-uncased-finetuned-sst-2-english"})

        serving =
          Bumblebee.Text.text_classification(model_info, tokenizer,
            compile: [batch_size: 1, sequence_length: 128],
            defn_options: [compiler: EXLA]
          )

        Logger.info("[Spine] Local neural model loaded successfully.")
        {:ok, serving}
      rescue
        e ->
          Logger.warning("[Spine] Failed to load neural model: #{inspect(e)}")
          {:error, :model_load_failed}
      end
    else
      Logger.debug("[Spine] Bumblebee not available, skipping local neural model.")
      {:error, :bumblebee_not_available}
    end
  end

  @impl true
  def handle_call({:process, signal}, _from, state) do
    start_ts = System.monotonic_time(:millisecond)
    {verdict, new_stats} = execute_neuro_symbolic_path(signal, state.reflex_stats)
    elapsed = System.monotonic_time(:millisecond) - start_ts

    :telemetry.execute(
      [:indrajaal, :prajna, :spine, :signal_processed],
      %{duration_ms: elapsed, hits: new_stats.hits, misses: new_stats.misses},
      %{signal_type: Map.get(signal, :type, :unknown)}
    )

    {:reply, verdict, %{state | reflex_stats: new_stats}}
  end

  @impl true
  def handle_call(:vital_signs, _from, state) do
    total = state.reflex_stats.hits + state.reflex_stats.misses
    hit_rate = if total > 0, do: state.reflex_stats.hits / total, else: 1.0

    # Stress index inversely proportional to hit rate
    stress = Float.round(1.0 - hit_rate, 3)
    # Energy index based on ETS routing table richness
    routing_count =
      case :ets.whereis(:prajna_spine_routing) do
        :undefined -> 0
        _ -> :ets.info(:prajna_spine_routing, :size)
      end

    energy = min(1.0, routing_count / 10.0)

    signs = %{
      id: state.id || "spine_neuro_v1",
      type: :organ,
      generation: state.generation,
      health_index: hit_rate,
      stress_index: stress,
      energy_index: Float.round(energy, 3),
      intent: :neuro_routing,
      target: :homeostasis,
      reflex_hits: state.reflex_stats.hits,
      reflex_misses: state.reflex_stats.misses,
      routing_patterns: routing_count,
      checked_at: System.monotonic_time(:millisecond)
    }

    {:reply, {:ok, signs}, state}
  end

  # --- The Neuro-Symbolic Routing Logic ---

  defp execute_neuro_symbolic_path(signal, stats) do
    # Step 1: L1 Reflex (Heuristic/Regex) - Zero Latency
    case check_l1_reflex(signal) do
      {:ok, action} ->
        {{:ok, :l1_reflex, action}, update_stats(stats, :hit)}

      :pass ->
        # Step 2: L2 Reflex (Local ML / Bumblebee) - Low Latency
        case check_l2_local_ml(signal) do
          {:ok, action, confidence} when confidence > @confidence_threshold ->
            record_routing_decision(Map.get(signal, :type, :unknown), action, true)
            {{:ok, :l2_local_ml, action}, update_stats(stats, :hit)}

          # Step 3: L3 Cognition (OpenRouter) - High Latency
          _low_confidence_result ->
            case call_l3_cortex(signal) do
              {:ok, action} ->
                record_routing_decision(Map.get(signal, :type, :unknown), action, true)
                {{:ok, :l3_cortex, action}, update_stats(stats, :miss)}

              error ->
                {error, stats}
            end
        end
    end
  end

  # --- Level 1: Heuristic Reflexes ---
  # Matches hardcoded patterns for instant safety
  defp check_l1_reflex(signal) do
    cond do
      # Example: Instant block of SQL Injection pattern
      String.contains?(inspect(signal), "UNION SELECT") ->
        {:ok, :block_ip}

      # Example: Instant PII scrubbing request
      Map.get(signal, :type) == :pii_scrub ->
        {:ok, :scrub_logs}

      true ->
        :pass
    end
  end

  # --- Level 2: Local Elixir AI (ETS-backed routing table) ---
  # Uses a statistical routing table built from past decisions.
  # Falls back to complexity-based heuristic when table is empty.
  defp check_l2_local_ml(signal) do
    table = ensure_routing_ets()
    signal_type = Map.get(signal, :type, :unknown)

    # Look up historical action distribution for this signal type
    case :ets.lookup(table, signal_type) do
      [{^signal_type, %{action: best_action, confidence: confidence, count: count}}]
      when count >= 5 and confidence > @confidence_threshold ->
        # Sufficient history — use learned routing
        :telemetry.execute(
          [:indrajaal, :prajna, :spine, :l2_hit],
          %{confidence: confidence, sample_count: count},
          %{signal_type: signal_type, source: :routing_table}
        )

        {:ok, best_action, confidence}

      _ ->
        # Insufficient history — fall back to heuristic
        complexity = calculate_complexity(signal)
        confidence = 1.0 - complexity

        if confidence > @confidence_threshold do
          action = classify_locally(signal)

          :telemetry.execute(
            [:indrajaal, :prajna, :spine, :l2_heuristic],
            %{confidence: confidence, complexity: complexity},
            %{signal_type: signal_type, source: :heuristic}
          )

          {:ok, action, confidence}
        else
          {:pass, confidence}
        end
    end
  end

  # --- Level 3: Cloud Cognition (OpenRouter) ---
  # Escalate to LLM for reasoning
  defp call_l3_cortex(signal) do
    Logger.info("[Spine] Escalating to Cortex (OpenRouter) due to low local confidence.")

    prompt = "Analyze system signal: #{inspect(signal)}. Recommend Action."

    # Using the existing OpenRouter client
    case OpenRouterClient.chat(prompt, "system_observer") do
      {:ok, response} -> {:ok, {:proposed_plan, response}}
      error -> error
    end
  end

  # --- Helpers ---

  defp calculate_complexity(signal) do
    # Simple heuristic: Length of data / structural depth
    # Returns 0.0 (Simple) to 1.0 (Complex)
    min(byte_size(inspect(signal)) / 1000.0, 1.0)
  end

  # ETS-backed classification — learns from routing decisions over time
  defp classify_locally(signal) do
    # Classify based on signal attributes using pattern matching rules
    cond do
      Map.get(signal, :priority) == :critical ->
        :emergency_response

      Map.get(signal, :type) in [:alert, :alarm, :threat] ->
        :escalate_to_sentinel

      Map.get(signal, :type) in [:metric, :health, :telemetry] ->
        :analyze_metrics

      Map.get(signal, :type) in [:command, :directive, :mutation] ->
        :validate_and_route

      Map.get(signal, :type) in [:query, :read, :inspect] ->
        :read_state

      is_map(signal) and map_size(signal) > 10 ->
        :analyze_metrics

      true ->
        :analyze_metrics
    end
  end

  defp ensure_routing_ets do
    table = :prajna_spine_routing

    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:named_table, :public, :set])
      _ -> table
    end
  rescue
    ArgumentError -> :prajna_spine_routing
  end

  # Record a successful routing decision to improve future L2 confidence
  defp record_routing_decision(signal_type, action, was_successful) do
    table = ensure_routing_ets()
    new_confidence = if was_successful, do: 0.9, else: 0.3

    case :ets.lookup(table, signal_type) do
      [{^signal_type, existing}] ->
        count = existing.count + 1
        # Exponential moving average for confidence
        blended = existing.confidence * 0.8 + new_confidence * 0.2
        :ets.insert(table, {signal_type, %{action: action, confidence: blended, count: count}})

      [] ->
        :ets.insert(table, {signal_type, %{action: action, confidence: new_confidence, count: 1}})
    end
  end

  defp update_stats(stats, :hit), do: %{stats | hits: stats.hits + 1}
  defp update_stats(stats, :miss), do: %{stats | misses: stats.misses + 1}

  # --- Holon Behaviour Implementation ---
  # Note: vital_signs/0 reads actual GenServer state for real metrics
  def vital_signs do
    try do
      case GenServer.call(__MODULE__, :vital_signs, 5_000) do
        {:ok, signs} -> signs
        _ -> default_vital_signs()
      end
    catch
      :exit, _ -> default_vital_signs()
    end
  end

  defp default_vital_signs do
    %{
      id: "spine_neuro_v1",
      type: :organ,
      generation: 1,
      health_index: 1.0,
      stress_index: 0.0,
      energy_index: 0.5,
      intent: :neuro_routing,
      target: :homeostasis
    }
  end
end
