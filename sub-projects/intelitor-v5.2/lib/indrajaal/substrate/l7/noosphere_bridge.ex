defmodule Indrajaal.Substrate.L7.NoosphereBridge do
  @moduledoc """
  L7 Noosphere Bridge — Ecosystem-level knowledge sharing and collective intelligence.

  Bridges the local holon's knowledge base with the wider federation noosphere
  (shared knowledge layer). Implements a publish/subscribe model for insights,
  patterns, and learned behaviors across the federation.

  ## STAMP Constraints
  - SC-FED-002: Maintain node autonomy
  - SC-SMRITI-063: Federation protocol for cross-holon sync
  """

  use GenServer
  require Logger

  defstruct shared_insights: [],
            received_insights: [],
            subscribers: [],
            published_count: 0,
            received_count: 0

  @type insight :: %{
          id: String.t(),
          source_holon: String.t(),
          category: atom(),
          payload: map(),
          confidence: float(),
          timestamp: DateTime.t()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec share_insight(atom(), map(), float()) :: {:ok, String.t()}
  def share_insight(category, payload, confidence \\ 0.8) do
    GenServer.call(__MODULE__, {:share, category, payload, confidence})
  end

  @spec receive_insight(insight()) :: :ok
  def receive_insight(insight) do
    GenServer.cast(__MODULE__, {:receive, insight})
  end

  @spec query_insights(atom()) :: [insight()]
  def query_insights(category) do
    GenServer.call(__MODULE__, {:query, category})
  end

  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ── GenServer ────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:share, category, payload, confidence}, _from, state) do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    insight = %{
      id: id,
      source_holon: to_string(Node.self()),
      category: category,
      payload: payload,
      confidence: confidence,
      timestamp: DateTime.utc_now()
    }

    publish_to_federation(insight)

    shared = [insight | Enum.take(state.shared_insights, 199)]

    {:reply, {:ok, id},
     %{state | shared_insights: shared, published_count: state.published_count + 1}}
  end

  @impl true
  def handle_call({:query, category}, _from, state) do
    all = state.shared_insights ++ state.received_insights
    matched = Enum.filter(all, &(&1.category == category))
    {:reply, matched, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       published: state.published_count,
       received: state.received_count,
       shared_buffer: length(state.shared_insights),
       received_buffer: length(state.received_insights)
     }, state}
  end

  @impl true
  def handle_cast({:receive, insight}, state) do
    received = [insight | Enum.take(state.received_insights, 499)]

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:noosphere",
        {:insight_received, insight}
      )
    rescue
      _ -> :ok
    end

    {:noreply, %{state | received_insights: received, received_count: state.received_count + 1}}
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp publish_to_federation(insight) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:noosphere",
      {:zenoh_publish, "indrajaal/noosphere/insights/#{insight.category}", insight}
    )
  rescue
    _ -> :ok
  end
end
