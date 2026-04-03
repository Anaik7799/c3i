defmodule Indrajaal.Cybernetic.EventSourcing.Projection do
  @moduledoc """
  Event Projections - Read Model Generation for v20.0.0

  Implements CQRS projections from event streams:
  - Real-time projection updates
  - Multiple projections per stream
  - Projection composition
  - Projection rebuilding

  ## Projection Model

  Projection: Event Stream → Read Model

  P(events) = reduce(events, init, handler)

  Where:
  - events = Source event stream
  - init = Initial projection state
  - handler = Event handler function

  ## Projection Types
  - **Aggregate**: Single entity state
  - **Summary**: Aggregated statistics
  - **Index**: Searchable index
  - **Timeline**: Time-ordered view

  ## STAMP Constraints
  - SC-PRJ-001: Projections MUST be rebuildable
  - SC-PRJ-002: Projection updates MUST be idempotent
  - SC-PRJ-003: Projection lag MUST be bounded
  - SC-PRJ-004: Failed projections MUST be retryable
  """

  use GenServer
  require Logger

  alias Indrajaal.Cybernetic.EventSourcing.EventStore

  @type projection_id :: String.t()
  @type projection_status :: :running | :paused | :error | :rebuilding

  @type projection_def :: %{
          id: projection_id(),
          name: String.t(),
          streams: [String.t()],
          handler: function(),
          init: map(),
          options: map()
        }

  @type projection_state :: %{
          definition: projection_def(),
          state: map(),
          version: map(),
          status: projection_status(),
          last_error: term() | nil,
          updated_at: DateTime.t()
        }

  @type store_state :: %{
          projections: map(),
          subscriptions: map()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new projection.
  """
  @spec create(projection_def()) :: {:ok, projection_id()} | {:error, term()}
  def create(definition) do
    GenServer.call(__MODULE__, {:create, definition})
  end

  @doc """
  Gets the current state of a projection.
  """
  @spec get_state(projection_id()) :: {:ok, map()} | {:error, :not_found}
  def get_state(projection_id) do
    GenServer.call(__MODULE__, {:get_state, projection_id})
  end

  @doc """
  Gets full projection info including metadata.
  """
  @spec get_info(projection_id()) :: {:ok, projection_state()} | {:error, :not_found}
  def get_info(projection_id) do
    GenServer.call(__MODULE__, {:get_info, projection_id})
  end

  @doc """
  Pauses a projection.
  """
  @spec pause(projection_id()) :: :ok | {:error, term()}
  def pause(projection_id) do
    GenServer.call(__MODULE__, {:pause, projection_id})
  end

  @doc """
  Resumes a paused projection.
  """
  @spec resume(projection_id()) :: :ok | {:error, term()}
  def resume(projection_id) do
    GenServer.call(__MODULE__, {:resume, projection_id})
  end

  @doc """
  Rebuilds a projection from scratch.
  """
  @spec rebuild(projection_id()) :: :ok | {:error, term()}
  def rebuild(projection_id) do
    GenServer.call(__MODULE__, {:rebuild, projection_id})
  end

  @doc """
  Deletes a projection.
  """
  @spec delete(projection_id()) :: :ok
  def delete(projection_id) do
    GenServer.call(__MODULE__, {:delete, projection_id})
  end

  @doc """
  Lists all projections.
  """
  @spec list() :: [projection_state()]
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Gets projection lag (events behind).
  """
  @spec lag(projection_id()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def lag(projection_id) do
    GenServer.call(__MODULE__, {:lag, projection_id})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      projections: %{},
      subscriptions: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:create, definition}, _from, state) do
    projection_id = definition.id || generate_projection_id()
    definition = Map.put(definition, :id, projection_id)

    # Initialize projection state
    projection = %{
      definition: definition,
      state: definition.init,
      version: Enum.into(definition.streams, %{}, fn s -> {s, 0} end),
      status: :running,
      last_error: nil,
      updated_at: DateTime.utc_now()
    }

    # Subscribe to streams
    Enum.each(definition.streams, fn stream ->
      EventStore.subscribe(stream, self())
    end)

    new_projections = Map.put(state.projections, projection_id, projection)
    new_subs = track_subscriptions(state.subscriptions, projection_id, definition.streams)

    # Catch up with existing events
    send(self(), {:catchup, projection_id})

    {:reply, {:ok, projection_id},
     %{state | projections: new_projections, subscriptions: new_subs}}
  end

  @impl true
  def handle_call({:get_state, projection_id}, _from, state) do
    case Map.get(state.projections, projection_id) do
      nil -> {:reply, {:error, :not_found}, state}
      proj -> {:reply, {:ok, proj.state}, state}
    end
  end

  @impl true
  def handle_call({:get_info, projection_id}, _from, state) do
    case Map.get(state.projections, projection_id) do
      nil -> {:reply, {:error, :not_found}, state}
      proj -> {:reply, {:ok, proj}, state}
    end
  end

  @impl true
  def handle_call({:pause, projection_id}, _from, state) do
    case Map.get(state.projections, projection_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      proj ->
        updated = %{proj | status: :paused}
        new_projections = Map.put(state.projections, projection_id, updated)
        {:reply, :ok, %{state | projections: new_projections}}
    end
  end

  @impl true
  def handle_call({:resume, projection_id}, _from, state) do
    case Map.get(state.projections, projection_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :paused} = proj ->
        updated = %{proj | status: :running}
        new_projections = Map.put(state.projections, projection_id, updated)
        send(self(), {:catchup, projection_id})
        {:reply, :ok, %{state | projections: new_projections}}

      _ ->
        {:reply, {:error, :not_paused}, state}
    end
  end

  @impl true
  def handle_call({:rebuild, projection_id}, _from, state) do
    case Map.get(state.projections, projection_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      proj ->
        # Reset to initial state (SC-PRJ-001: rebuildable)
        updated = %{
          proj
          | state: proj.definition.init,
            version: Enum.into(proj.definition.streams, %{}, fn s -> {s, 0} end),
            status: :rebuilding
        }

        new_projections = Map.put(state.projections, projection_id, updated)
        send(self(), {:catchup, projection_id})
        {:reply, :ok, %{state | projections: new_projections}}
    end
  end

  @impl true
  def handle_call({:delete, projection_id}, _from, state) do
    new_projections = Map.delete(state.projections, projection_id)
    new_subs = remove_subscriptions(state.subscriptions, projection_id)
    {:reply, :ok, %{state | projections: new_projections, subscriptions: new_subs}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.projections), state}
  end

  @impl true
  def handle_call({:lag, projection_id}, _from, state) do
    case Map.get(state.projections, projection_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      proj ->
        total_lag =
          Enum.reduce(proj.definition.streams, 0, fn stream, acc ->
            current_version = EventStore.stream_version(stream)
            proj_version = Map.get(proj.version, stream, 0)
            acc + max(0, current_version - proj_version)
          end)

        {:reply, {:ok, total_lag}, state}
    end
  end

  @impl true
  def handle_info({:event, stream, event}, state) do
    # Find projections subscribed to this stream
    projection_ids = Map.get(state.subscriptions, stream, [])

    new_projections =
      Enum.reduce(projection_ids, state.projections, fn proj_id, projs ->
        case Map.get(projs, proj_id) do
          nil ->
            projs

          %{status: :paused} ->
            projs

          proj ->
            updated = apply_event(proj, stream, event)
            Map.put(projs, proj_id, updated)
        end
      end)

    {:noreply, %{state | projections: new_projections}}
  end

  @impl true
  def handle_info({:catchup, projection_id}, state) do
    case Map.get(state.projections, projection_id) do
      nil ->
        {:noreply, state}

      proj ->
        updated = catchup_projection(proj)
        new_projections = Map.put(state.projections, projection_id, updated)
        {:noreply, %{state | projections: new_projections}}
    end
  end

  # Private helpers

  defp generate_projection_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp track_subscriptions(subs, projection_id, streams) do
    Enum.reduce(streams, subs, fn stream, acc ->
      stream_projs = Map.get(acc, stream, [])
      Map.put(acc, stream, [projection_id | stream_projs])
    end)
  end

  defp remove_subscriptions(subs, projection_id) do
    Enum.into(subs, %{}, fn {stream, projs} ->
      {stream, Enum.reject(projs, &(&1 == projection_id))}
    end)
  end

  defp apply_event(proj, stream, event) do
    current_version = Map.get(proj.version, stream, 0)

    # Check for idempotency (SC-PRJ-002)
    if event.version <= current_version do
      proj
    else
      try do
        new_state = proj.definition.handler.(proj.state, event)

        %{
          proj
          | state: new_state,
            version: Map.put(proj.version, stream, event.version),
            updated_at: DateTime.utc_now(),
            status:
              if(proj.status == :rebuilding and caught_up?(proj), do: :running, else: proj.status)
        }
      rescue
        e ->
          Logger.error("Projection #{proj.definition.id} error: #{inspect(e)}")

          %{
            proj
            | status: :error,
              last_error: e
          }
      end
    end
  end

  defp catchup_projection(proj) do
    Enum.reduce(proj.definition.streams, proj, fn stream, current_proj ->
      current_version = Map.get(current_proj.version, stream, 0)

      case EventStore.read(stream, from_version: current_version) do
        {:ok, events} ->
          Enum.reduce(events, current_proj, fn event, p ->
            apply_event(p, stream, event)
          end)

        _ ->
          current_proj
      end
    end)
  end

  defp caught_up?(proj) do
    Enum.all?(proj.definition.streams, fn stream ->
      current_version = EventStore.stream_version(stream)
      proj_version = Map.get(proj.version, stream, 0)
      proj_version >= current_version
    end)
  end
end
