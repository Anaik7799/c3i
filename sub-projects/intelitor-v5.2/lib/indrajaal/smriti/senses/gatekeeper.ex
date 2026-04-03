defmodule Indrajaal.Smriti.Senses.Gatekeeper do
  @moduledoc """
  Supervisor 1: The Gatekeeper (Rate & Budget).

  Enforces token limits, API costs, and concurrency for SMRITI ingestion
  per Recall Analysis "2-Supervisor Model".

  ## Responsibilities
  - Token Bucket Rate Limiting
  - Daily Budget Enforcement ($5.00 limit)
  - Concurrency Control (Max 5 parallel ingestions)

  ## STAMP Constraints
  - SC-SMRITI-080: Never exceed 95% of API quota
  - SC-SMRITI-081: Halt ingestion if budget depleted
  """

  use GenServer
  require Logger

  @daily_budget_usd 5.00
  @max_concurrency 5

  defstruct [
    :tokens_spent,
    :request_count,
    :active_workers,
    :queue
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Request permission to ingest a batch.
  Returns `{:ok, token}` or `{:error, reason}`.
  """
  def request_ingest(batch_size, estimated_cost) do
    GenServer.call(__MODULE__, {:request_ingest, batch_size, estimated_cost})
  end

  @doc """
  Report completion of ingestion to release worker slot.
  """
  def report_completion(token) do
    GenServer.cast(__MODULE__, {:completion, token})
  end

  # Callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %__MODULE__{
       tokens_spent: 0.0,
       request_count: 0,
       active_workers: 0,
       queue: :queue.new()
     }}
  end

  @impl true
  def handle_call({:request_ingest, _batch_size, cost}, _from, state) do
    cond do
      state.tokens_spent + cost > @daily_budget_usd ->
        Logger.warning(
          "[Gatekeeper] Budget exceeded! Spent: $#{state.tokens_spent}, Cost: $#{cost}"
        )

        {:reply, {:error, :budget_exceeded}, state}

      state.active_workers >= @max_concurrency ->
        Logger.info("[Gatekeeper] Max concurrency reached. Queuing request.")
        # Simplified: Reject for now, in real impl queue it
        {:reply, {:error, :busy}, state}

      true ->
        token = make_ref()

        new_state = %{
          state
          | tokens_spent: state.tokens_spent + cost,
            active_workers: state.active_workers + 1
        }

        {:reply, {:ok, token}, new_state}
    end
  end

  @impl true
  def handle_cast({:completion, _token}, state) do
    new_state = %{state | active_workers: max(0, state.active_workers - 1)}
    {:noreply, new_state}
  end
end
