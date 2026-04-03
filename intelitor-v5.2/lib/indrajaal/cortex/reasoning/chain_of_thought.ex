defmodule Indrajaal.Cortex.Reasoning.ChainOfThought do
  @moduledoc """
  [AGENT_RECREATION_GENOME]
  Purpose: Persistent reasoning buffer for the Autonomic Cortex.
  Function: Captures internal "Thinking" steps before OODA 'Decide' transitions.
  STAMP: SC-DRIFT-001, T22.1.1
  Recovery:
  - Supervisor: `Indrajaal.Cortex.Supervisor`
  - Logic: Implements a ring-buffer of semantic reasoning tokens.
  - Verification: Emits 'thought_trace' events to Zenoh.
  [/AGENT_RECREATION_GENOME]
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Cortex] Chain-of-Thought reasoning buffer initialized.")
    {:ok, %{current_thought: nil, history: []}}
  end

  # --- Public API ---

  @doc "Start a new reasoning chain for a specific task"
  def start_chain(task_id) do
    GenServer.call(__MODULE__, {:start_chain, task_id})
  end

  @doc "Record a reasoning step"
  def think(step_detail) do
    GenServer.cast(__MODULE__, {:think, step_detail})
  end

  @doc "Finalize the chain and produce a conclusion"
  def finalize do
    GenServer.call(__MODULE__, :finalize)
  end

  # --- Callbacks ---

  @impl true
  def handle_call({:start_chain, task_id}, _from, state) do
    Logger.debug("[Cortex] Starting CoT chain for task: #{task_id}")
    {:reply, :ok, %{state | current_thought: task_id, history: []}}
  end

  @impl true
  def handle_call(:finalize, _from, state) do
    conclusion = Enum.reverse(state.history) |> Enum.join(" -> ")
    {:reply, {:ok, conclusion}, %{state | current_thought: nil, history: []}}
  end

  @impl true
  def handle_cast({:think, step}, state) do
    new_history = [step | state.history] |> Enum.take(20)

    # ZUIP: Publish thought trace to Zenoh mesh
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohNeuralStream) do
      Indrajaal.Observability.ZenohNeuralStream.stream_state(
        :cortex,
        :thought_trace,
        %{task: state.current_thought, step: step}
      )
    end

    {:noreply, %{state | history: new_history}}
  end
end
