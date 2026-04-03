defmodule Indrajaal.Information.PubSubRouter do
  @moduledoc """
  PubSub Router — L2 Information Layer

  ## Design Intent
  GenServer that routes messages between PubSub topics based on a
  rule table stored in ETS. Routes are looked up in O(1) time.
  Messages that match no route are placed into a dead-letter queue
  (capped at 100 entries, FIFO eviction). All routing decisions are
  instrumented via :telemetry.

  ### Route Schema
  A route is a map with:
  - `:id`         — unique atom identifier
  - `:source`     — source topic string (exact match)
  - `:dest`       — destination topic string
  - `:match_fn`   — `(payload :: map() -> boolean())` — optional payload predicate

  Routes are indexed in ETS by `source` topic so that a broadcast on a
  source topic can be dispatched to all matching destinations in one ETS
  scan.

  ### Dead Letter Queue
  Unroutable messages are appended to an in-process :queue. When the queue
  reaches 100 items the oldest entry is dropped. The dead letter queue is
  accessible via `dead_letter_queue/0`.

  ## STAMP Constraints
  - SC-PUBSUB-001: PubSub routing MUST be rule-based and auditable
  - SC-DIST-002: Messages MUST be reliably routed between nodes

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @route_table :pubsub_router_routes
  @dead_letter_max 100
  @telemetry_routed [:indrajaal, :information, :pubsub_routed]
  @telemetry_dropped [:indrajaal, :information, :pubsub_dropped]
  @telemetry_dead_lettered [:indrajaal, :information, :pubsub_dead_lettered]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type route_id :: atom()
  @type topic :: String.t()
  @type match_fn :: (map() -> boolean())

  @type route :: %{
          id: route_id(),
          source: topic(),
          dest: topic(),
          match_fn: match_fn() | nil
        }

  @type dead_letter :: %{
          source: topic(),
          payload: map(),
          reason: :no_route | :match_failed,
          ts_ms: non_neg_integer()
        }

  @type state :: %{
          dead_letter_queue: :queue.queue(),
          dead_letter_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the PubSubRouter.

  Options:
  - `:routes` — initial list of `t:route/0` maps to load
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Adds a routing rule."
  @spec add_route(route()) :: :ok
  def add_route(%{id: _, source: _, dest: _} = route) do
    GenServer.cast(@name, {:add_route, route})
  end

  @doc "Removes a routing rule by id."
  @spec remove_route(route_id()) :: :ok
  def remove_route(id) when is_atom(id) do
    GenServer.cast(@name, {:remove_route, id})
  end

  @doc """
  Routes a message payload arriving on `source` topic.

  Returns `{:ok, destinations}` with the list of topics the message was
  forwarded to, or `{:dead_lettered, :no_route}` / `{:dead_lettered, :match_failed}`.
  """
  @spec route(topic(), map()) :: {:ok, [topic()]} | {:dead_lettered, :no_route | :match_failed}
  def route(source, payload) when is_binary(source) and is_map(payload) do
    GenServer.call(@name, {:route, source, payload})
  end

  @doc "Lists all current routing rules (fast ETS read)."
  @spec list_routes() :: [route()]
  def list_routes do
    case :ets.whereis(@route_table) do
      :undefined ->
        []

      _ ->
        :ets.tab2list(@route_table)
        |> Enum.map(fn {_id, route} -> route end)
    end
  end

  @doc "Returns all entries in the dead letter queue."
  @spec dead_letter_queue() :: [dead_letter()]
  def dead_letter_queue do
    GenServer.call(@name, :dead_letter_queue)
  end

  @doc "Drains and returns all dead letter entries, clearing the queue."
  @spec drain_dead_letters() :: [dead_letter()]
  def drain_dead_letters do
    GenServer.call(@name, :drain_dead_letters)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@route_table, [:named_table, :public, read_concurrency: true])

    initial_routes = Keyword.get(opts, :routes, [])
    Enum.each(initial_routes, fn route -> :ets.insert(@route_table, {route.id, route}) end)

    Logger.info("[PubSubRouter] L2 started — initial_routes=#{length(initial_routes)}")

    state = %{
      dead_letter_queue: :queue.new(),
      dead_letter_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:add_route, route}, state) do
    normalized = Map.put_new(route, :match_fn, nil)
    :ets.insert(@route_table, {route.id, normalized})

    Logger.debug(
      "[PubSubRouter] Route added: #{inspect(route.id)} #{route.source} -> #{route.dest}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove_route, id}, state) do
    :ets.delete(@route_table, id)
    Logger.debug("[PubSubRouter] Route removed: #{inspect(id)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:route, source, payload}, _from, state) do
    matching_routes =
      :ets.tab2list(@route_table)
      |> Enum.filter(fn {_id, route} -> route.source == source end)
      |> Enum.map(fn {_id, route} -> route end)

    case matching_routes do
      [] ->
        new_state = dead_letter(state, source, payload, :no_route)

        :telemetry.execute(@telemetry_dropped, %{count: 1}, %{
          source: source,
          reason: :no_route
        })

        {:reply, {:dead_lettered, :no_route}, new_state}

      routes ->
        passed_routes =
          Enum.filter(routes, fn route ->
            case route.match_fn do
              nil -> true
              f when is_function(f, 1) -> apply(f, [payload])
            end
          end)

        case passed_routes do
          [] ->
            new_state = dead_letter(state, source, payload, :match_failed)

            :telemetry.execute(@telemetry_dropped, %{count: 1}, %{
              source: source,
              reason: :match_failed
            })

            {:reply, {:dead_lettered, :match_failed}, new_state}

          _ ->
            destinations =
              Enum.map(passed_routes, fn route ->
                Phoenix.PubSub.broadcast(Indrajaal.PubSub, route.dest, {:routed, source, payload})
                route.dest
              end)

            :telemetry.execute(@telemetry_routed, %{count: length(destinations)}, %{
              source: source,
              destinations: destinations
            })

            {:reply, {:ok, destinations}, state}
        end
    end
  end

  @impl true
  def handle_call(:dead_letter_queue, _from, state) do
    entries = :queue.to_list(state.dead_letter_queue)
    {:reply, entries, state}
  end

  @impl true
  def handle_call(:drain_dead_letters, _from, state) do
    entries = :queue.to_list(state.dead_letter_queue)

    {:reply, entries, %{state | dead_letter_queue: :queue.new(), dead_letter_count: 0}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec dead_letter(state(), topic(), map(), :no_route | :match_failed) :: state()
  defp dead_letter(state, source, payload, reason) do
    entry = %{
      source: source,
      payload: payload,
      reason: reason,
      ts_ms: System.monotonic_time(:millisecond)
    }

    Logger.warning("[PubSubRouter] Dead letter: source=#{source} reason=#{reason}")

    :telemetry.execute(@telemetry_dead_lettered, %{count: 1}, %{source: source, reason: reason})

    {new_queue, new_count} =
      if state.dead_letter_count >= @dead_letter_max do
        # Evict the oldest entry (front of queue)
        {{:value, _old}, trimmed} = :queue.out(state.dead_letter_queue)
        {:queue.in(entry, trimmed), state.dead_letter_count}
      else
        {:queue.in(entry, state.dead_letter_queue), state.dead_letter_count + 1}
      end

    %{state | dead_letter_queue: new_queue, dead_letter_count: new_count}
  end
end
