defmodule Indrajaal.Core.Reflex.FineTuningCollector do
  @moduledoc """
  Captures training data pairs from external API inference for local fine-tuning.

  When InferenceRouter successfully uses the external path (OpenRouter), this
  GenServer logs `{input, golden_output, model, task_type}` tuples to DuckDB
  for later LoRA fine-tuning on the local Mojo MAX model.

  ## STAMP Constraints
  - SC-SOVEREIGNTY-002: Training data capture from external inference
  - SC-SOVEREIGNTY-003: Fine-tune trigger at threshold (100 new pairs)
  - SC-SOVEREIGNTY-004: Training data persisted to DuckDB

  ## Change History
  | Version | Date       | Author | Change               |
  |---------|------------|--------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @check_interval_ms 3_600_000
  @finetune_threshold 100
  @pubsub_topic "prajna:fine_tuning"
  @zenoh_trigger_key "indrajaal/training/finetune_trigger"

  defstruct [
    :last_finetune_at,
    pairs_since_finetune: 0,
    total_pairs: 0,
    started_at: nil
  ]

  # ─────────────────────────────────────────────────────────────────────
  # PUBLIC API
  # ─────────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Record a training pair from a successful external inference.

  Called by InferenceRouter when the external (OpenRouter) path succeeds.
  """
  @spec record_pair(String.t(), String.t(), String.t(), atom()) :: :ok
  def record_pair(input, output, model, task_type) do
    GenServer.cast(@name, {:record_pair, input, output, model, task_type})
  end

  @doc "Returns collector statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ─────────────────────────────────────────────────────────────────────
  # GENSERVER CALLBACKS
  # ─────────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    schedule_finetune_check()

    state = %__MODULE__{
      started_at: DateTime.utc_now()
    }

    Logger.info("[FineTuningCollector] started — threshold=#{@finetune_threshold} pairs")
    {:ok, state}
  end

  @impl true
  def handle_cast({:record_pair, input, output, model, task_type}, state) do
    persist_training_pair(input, output, model, task_type)

    new_state = %{
      state
      | pairs_since_finetune: state.pairs_since_finetune + 1,
        total_pairs: state.total_pairs + 1
    }

    # Check if we've crossed the fine-tuning threshold
    if new_state.pairs_since_finetune >= @finetune_threshold do
      trigger_finetune(new_state)
      {:noreply, %{new_state | pairs_since_finetune: 0, last_finetune_at: DateTime.utc_now()}}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_pairs: state.total_pairs,
      pairs_since_finetune: state.pairs_since_finetune,
      last_finetune_at: state.last_finetune_at,
      finetune_threshold: @finetune_threshold,
      progress_pct: Float.round(state.pairs_since_finetune / @finetune_threshold * 100, 1),
      started_at: state.started_at
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:check_finetune, state) do
    schedule_finetune_check()

    if state.pairs_since_finetune >= @finetune_threshold do
      Logger.info(
        "[FineTuningCollector] hourly check — #{state.pairs_since_finetune} pairs ready, triggering fine-tune"
      )

      trigger_finetune(state)
      {:noreply, %{state | pairs_since_finetune: 0, last_finetune_at: DateTime.utc_now()}}
    else
      Logger.debug(
        "[FineTuningCollector] hourly check — #{state.pairs_since_finetune}/#{@finetune_threshold} pairs"
      )

      {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ─────────────────────────────────────────────────────────────────────
  # PRIVATE
  # ─────────────────────────────────────────────────────────────────────

  defp persist_training_pair(input, output, model, task_type) do
    # Persist to DuckDB training_data table via PubSub bridge
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:training_pair,
       %{
         input: input,
         output: output,
         model: model,
         task_type: task_type,
         timestamp: DateTime.utc_now()
       }}
    )

    Logger.debug(
      "[FineTuningCollector] recorded pair model=#{model} task=#{task_type} input_len=#{String.length(input)}"
    )
  end

  defp trigger_finetune(state) do
    Logger.info(
      "[FineTuningCollector] triggering fine-tune — #{state.pairs_since_finetune} new pairs, #{state.total_pairs} total"
    )

    # Publish trigger to Zenoh for Mojo container to pick up
    trigger_payload =
      Jason.encode!(%{
        action: "finetune",
        pairs_count: state.pairs_since_finetune,
        total_pairs: state.total_pairs,
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      })

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:reflex",
      {:zenoh_publish, @zenoh_trigger_key, trigger_payload}
    )

    # Notify Prajna cockpit
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:finetune_triggered, %{pairs: state.pairs_since_finetune}}
    )
  end

  defp schedule_finetune_check do
    Process.send_after(self(), :check_finetune, @check_interval_ms)
  end
end
