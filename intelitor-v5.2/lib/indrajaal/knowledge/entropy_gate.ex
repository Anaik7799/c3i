defmodule Indrajaal.Knowledge.EntropyGate do
  @moduledoc """
  Entropy Gate — L4 Intelligence Layer (Knowledge Subsystem)

  ## Design Intent
  Guards knowledge ingestion by computing Shannon entropy of incoming data.
  Documents with entropy above the drift threshold (default 0.2) are blocked
  to prevent knowledge base contamination from noisy or adversarial input.

  Uses a sliding window of recent entropy measurements to detect sustained
  drift patterns vs. single-document anomalies.

  ## STAMP Constraints
  - SC-IKE-002: Entropy gating (blocked if > 0.2)
  - SC-IKE-003: Drift detection scoring
  - SC-SMRITI-140: All evolution events recorded
  - SC-SEM-001: Semantic analysis pipeline MUST be observable

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :entropy_gate_history
  @drift_threshold 0.2
  @window_size 50
  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type entropy_score :: float()
  @type gate_decision :: :allow | :block | :review

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Evaluate a document for ingestion. Returns gate decision based on entropy."
  @spec evaluate(String.t()) :: {gate_decision(), entropy_score()}
  def evaluate(text) when is_binary(text) do
    GenServer.call(@name, {:evaluate, text})
  end

  @doc "Get current drift score (rolling average of recent entropy deltas)."
  @spec drift_score() :: float()
  def drift_score do
    GenServer.call(@name, :drift_score)
  end

  @doc "Get gate statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  @doc "Compute Shannon entropy of a text string (bits per character)."
  @spec shannon_entropy(String.t()) :: float()
  def shannon_entropy(text) when is_binary(text) do
    compute_entropy(text)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    threshold = Keyword.get(opts, :drift_threshold, @drift_threshold)

    :ets.new(@table, [:named_table, :public, :ordered_set])

    state = %{
      drift_threshold: threshold,
      baseline_entropy: nil,
      recent_entropies: :queue.new(),
      total_evaluated: 0,
      total_allowed: 0,
      total_blocked: 0,
      total_review: 0
    }

    Logger.info("[EntropyGate] Started — threshold=#{threshold} [SC-IKE-002]")

    {:ok, state}
  end

  @impl true
  def handle_call({:evaluate, text}, _from, state) do
    entropy = compute_entropy(text)
    {decision, state2} = make_decision(entropy, state)

    # Record to ETS history
    :ets.insert(@table, {System.system_time(:millisecond), entropy, decision})

    # Update counters
    state3 = update_counters(state2, decision)

    emit_telemetry(entropy, decision)

    if decision == :block do
      Logger.warning(
        "[EntropyGate] BLOCKED document — entropy=#{Float.round(entropy, 4)} drift=#{Float.round(compute_drift(state3), 4)} [SC-IKE-002]"
      )
    end

    {:reply, {decision, entropy}, state3}
  end

  @impl true
  def handle_call(:drift_score, _from, state) do
    {:reply, Float.round(compute_drift(state), 4), state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_evaluated: state.total_evaluated,
      total_allowed: state.total_allowed,
      total_blocked: state.total_blocked,
      total_review: state.total_review,
      baseline_entropy: state.baseline_entropy,
      current_drift: Float.round(compute_drift(state), 4),
      drift_threshold: state.drift_threshold,
      window_size: :queue.len(state.recent_entropies)
    }

    {:reply, stats, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_entropy(text) when byte_size(text) == 0, do: 0.0

  defp compute_entropy(text) do
    chars = String.graphemes(text)
    total = length(chars)

    if total == 0 do
      0.0
    else
      freqs =
        Enum.reduce(chars, %{}, fn c, acc ->
          Map.update(acc, c, 1, &(&1 + 1))
        end)

      freqs
      |> Map.values()
      |> Enum.reduce(0.0, fn count, acc ->
        p = count / total
        if p > 0, do: acc - p * :math.log2(p), else: acc
      end)
    end
  end

  defp make_decision(entropy, state) do
    # Update sliding window
    window = :queue.in(entropy, state.recent_entropies)

    window2 =
      if :queue.len(window) > @window_size do
        {_, q} = :queue.out(window)
        q
      else
        window
      end

    state2 = %{state | recent_entropies: window2}

    # Establish baseline from first 10 samples
    state3 =
      if is_nil(state.baseline_entropy) and :queue.len(window2) >= 10 do
        values = :queue.to_list(window2)
        baseline = Enum.sum(values) / length(values)
        %{state2 | baseline_entropy: baseline}
      else
        state2
      end

    drift = compute_drift(state3)

    decision =
      cond do
        is_nil(state3.baseline_entropy) -> :allow
        drift > state3.drift_threshold -> :block
        drift > state3.drift_threshold * 0.7 -> :review
        true -> :allow
      end

    {decision, state3}
  end

  defp compute_drift(%{baseline_entropy: nil}), do: 0.0

  defp compute_drift(state) do
    values = :queue.to_list(state.recent_entropies)

    if length(values) == 0 do
      0.0
    else
      current_avg = Enum.sum(values) / length(values)
      abs(current_avg - state.baseline_entropy)
    end
  end

  defp update_counters(state, decision) do
    state = %{state | total_evaluated: state.total_evaluated + 1}

    case decision do
      :allow -> %{state | total_allowed: state.total_allowed + 1}
      :block -> %{state | total_blocked: state.total_blocked + 1}
      :review -> %{state | total_review: state.total_review + 1}
    end
  end

  defp emit_telemetry(entropy, decision) do
    :telemetry.execute(
      [:indrajaal, :knowledge, :entropy_gate, :evaluate],
      %{entropy: entropy},
      %{decision: decision}
    )
  rescue
    _ -> :ok
  end
end
