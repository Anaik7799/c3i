defmodule Indrajaal.Cybernetic.EventSourcing.Replay do
  @moduledoc """
  Event Replay - Controlled Event Re-processing for v20.0.0

  Implements event replay capabilities:
  - Filtered replay by type, time range, or predicate
  - Speed-controlled replay (real-time, accelerated, instant)
  - Replay with transformation (event migration)
  - Audit and debugging replay

  ## Replay Model

  Replay(events, filter, speed, transform) → effects

  Where:
  - events = Source event stream
  - filter = Predicate function
  - speed = Replay speed multiplier
  - transform = Optional event transformation

  ## Replay Modes
  - **Instant**: Process all events immediately
  - **Real-time**: Respect original timing
  - **Accelerated**: Speed multiplier (2x, 10x, etc.)
  - **Stepped**: One event at a time

  ## STAMP Constraints
  - SC-RPL-001: Replay MUST be idempotent
  - SC-RPL-002: Side effects MUST be controlled
  - SC-RPL-003: Original events MUST NOT be modified
  - SC-RPL-004: Replay progress MUST be trackable
  """

  use GenServer
  require Logger

  alias Indrajaal.Cybernetic.EventSourcing.EventStore

  @type replay_mode :: :instant | :realtime | :accelerated | :stepped
  @type replay_status :: :idle | :running | :paused | :completed | :error

  @type replay_config :: %{
          stream: String.t(),
          from_version: non_neg_integer(),
          to_version: non_neg_integer() | nil,
          filter: function() | nil,
          transform: function() | nil,
          handler: function(),
          mode: replay_mode(),
          speed: float(),
          batch_size: non_neg_integer()
        }

  @type replay_state :: %{
          config: replay_config(),
          status: replay_status(),
          current_version: non_neg_integer(),
          events_processed: non_neg_integer(),
          errors: [map()],
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new replay session.
  """
  @spec start_replay(replay_config()) :: {:ok, String.t()} | {:error, term()}
  def start_replay(config) do
    GenServer.call(__MODULE__, {:start_replay, config})
  end

  @doc """
  Pauses a running replay.
  """
  @spec pause(String.t()) :: :ok | {:error, term()}
  def pause(replay_id) do
    GenServer.call(__MODULE__, {:pause, replay_id})
  end

  @doc """
  Resumes a paused replay.
  """
  @spec resume(String.t()) :: :ok | {:error, term()}
  def resume(replay_id) do
    GenServer.call(__MODULE__, {:resume, replay_id})
  end

  @doc """
  Stops a replay session.
  """
  @spec stop(String.t()) :: :ok
  def stop(replay_id) do
    GenServer.call(__MODULE__, {:stop, replay_id})
  end

  @doc """
  Gets replay status.
  """
  @spec status(String.t()) :: {:ok, replay_state()} | {:error, :not_found}
  def status(replay_id) do
    GenServer.call(__MODULE__, {:status, replay_id})
  end

  @doc """
  Steps forward one event (for stepped mode).
  """
  @spec step(String.t()) :: {:ok, map()} | {:error, term()}
  def step(replay_id) do
    GenServer.call(__MODULE__, {:step, replay_id})
  end

  @doc """
  Performs instant replay with handler.
  """
  @spec instant_replay(String.t(), function(), Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def instant_replay(stream, handler, opts \\ []) do
    config = %{
      stream: stream,
      from_version: Keyword.get(opts, :from_version, 0),
      to_version: Keyword.get(opts, :to_version),
      filter: Keyword.get(opts, :filter),
      transform: Keyword.get(opts, :transform),
      handler: handler,
      mode: :instant,
      speed: 1.0,
      batch_size: Keyword.get(opts, :batch_size, 100)
    }

    do_instant_replay(config)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{replays: %{}}}
  end

  @impl true
  def handle_call({:start_replay, config}, _from, state) do
    replay_id = generate_replay_id()

    replay_state = %{
      config: config,
      status: :running,
      current_version: config.from_version,
      events_processed: 0,
      errors: [],
      started_at: DateTime.utc_now(),
      completed_at: nil
    }

    new_replays = Map.put(state.replays, replay_id, replay_state)

    # Start replay process
    if config.mode != :stepped do
      send(self(), {:process_replay, replay_id})
    end

    {:reply, {:ok, replay_id}, %{state | replays: new_replays}}
  end

  @impl true
  def handle_call({:pause, replay_id}, _from, state) do
    case Map.get(state.replays, replay_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      replay ->
        updated = %{replay | status: :paused}
        new_replays = Map.put(state.replays, replay_id, updated)
        {:reply, :ok, %{state | replays: new_replays}}
    end
  end

  @impl true
  def handle_call({:resume, replay_id}, _from, state) do
    case Map.get(state.replays, replay_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :paused} = replay ->
        updated = %{replay | status: :running}
        new_replays = Map.put(state.replays, replay_id, updated)
        send(self(), {:process_replay, replay_id})
        {:reply, :ok, %{state | replays: new_replays}}

      _ ->
        {:reply, {:error, :not_paused}, state}
    end
  end

  @impl true
  def handle_call({:stop, replay_id}, _from, state) do
    new_replays = Map.delete(state.replays, replay_id)
    {:reply, :ok, %{state | replays: new_replays}}
  end

  @impl true
  def handle_call({:status, replay_id}, _from, state) do
    case Map.get(state.replays, replay_id) do
      nil -> {:reply, {:error, :not_found}, state}
      replay -> {:reply, {:ok, replay}, state}
    end
  end

  @impl true
  def handle_call({:step, replay_id}, _from, state) do
    case Map.get(state.replays, replay_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :completed} ->
        {:reply, {:error, :completed}, state}

      replay ->
        {result, updated_replay} = process_single_event(replay)
        new_replays = Map.put(state.replays, replay_id, updated_replay)
        {:reply, result, %{state | replays: new_replays}}
    end
  end

  @impl true
  def handle_info({:process_replay, replay_id}, state) do
    case Map.get(state.replays, replay_id) do
      nil ->
        {:noreply, state}

      %{status: :paused} ->
        {:noreply, state}

      %{status: :completed} ->
        {:noreply, state}

      replay ->
        {updated_replay, continue} = process_batch(replay)
        new_replays = Map.put(state.replays, replay_id, updated_replay)

        if continue do
          # Schedule next batch based on mode
          delay = calculate_delay(replay.config)
          Process.send_after(self(), {:process_replay, replay_id}, delay)
        end

        {:noreply, %{state | replays: new_replays}}
    end
  end

  # Private helpers

  defp generate_replay_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp do_instant_replay(config) do
    case EventStore.read(config.stream,
           from_version: config.from_version,
           to_version: config.to_version
         ) do
      {:ok, events} ->
        # Apply filter
        filtered =
          if config.filter do
            Enum.filter(events, config.filter)
          else
            events
          end

        # Apply transform and handler
        processed =
          Enum.reduce(filtered, 0, fn event, count ->
            transformed =
              if config.transform do
                config.transform.(event)
              else
                event
              end

            config.handler.(transformed)
            count + 1
          end)

        {:ok, processed}

      error ->
        error
    end
  end

  defp process_batch(replay) do
    config = replay.config
    batch_size = config.batch_size

    case EventStore.read(config.stream,
           from_version: replay.current_version,
           limit: batch_size
         ) do
      {:ok, []} ->
        # No more events
        completed = %{
          replay
          | status: :completed,
            completed_at: DateTime.utc_now()
        }

        {completed, false}

      {:ok, events} ->
        # Check to_version limit
        events =
          if config.to_version do
            Enum.filter(events, fn e -> e.version <= config.to_version end)
          else
            events
          end

        # Apply filter
        filtered =
          if config.filter do
            Enum.filter(events, config.filter)
          else
            events
          end

        # Process events
        {processed, errors} =
          Enum.reduce(filtered, {0, []}, fn event, {count, errs} ->
            transformed =
              if config.transform do
                config.transform.(event)
              else
                event
              end

            try do
              config.handler.(transformed)
              {count + 1, errs}
            rescue
              e ->
                {count, [%{event: event.id, error: inspect(e)} | errs]}
            end
          end)

        last_version =
          if Enum.empty?(events) do
            replay.current_version
          else
            List.last(events).version
          end

        # Check if we've reached the end
        at_end =
          length(events) < batch_size or (config.to_version && last_version >= config.to_version)

        updated = %{
          replay
          | current_version: last_version,
            events_processed: replay.events_processed + processed,
            errors: errors ++ replay.errors,
            status: if(at_end, do: :completed, else: :running),
            completed_at: if(at_end, do: DateTime.utc_now(), else: nil)
        }

        {updated, not at_end}

      {:error, reason} ->
        Logger.error("Replay error: #{inspect(reason)}")
        {%{replay | status: :error}, false}
    end
  end

  defp process_single_event(replay) do
    config = replay.config

    case EventStore.read(config.stream,
           from_version: replay.current_version,
           limit: 1
         ) do
      {:ok, []} ->
        {mark_completed(), mark_completed_state(replay)}

      {:ok, [event]} ->
        process_event(event, replay, config)

      error ->
        {error, replay}
    end
  end

  defp mark_completed, do: {:ok, :completed}

  defp mark_completed_state(replay) do
    %{
      replay
      | status: :completed,
        completed_at: DateTime.utc_now()
    }
  end

  defp process_event(event, replay, config) do
    cond do
      config.to_version && event.version > config.to_version ->
        {mark_completed(), mark_completed_state(replay)}

      config.filter && not config.filter.(event) ->
        {event_skipped(), %{replay | current_version: event.version}}

      true ->
        handle_event_transformation(event, replay, config)
    end
  end

  defp event_skipped, do: {:ok, :skipped}

  defp handle_event_transformation(event, replay, config) do
    transformed =
      if config.transform do
        config.transform.(event)
      else
        event
      end

    try do
      config.handler.(transformed)

      updated = %{
        replay
        | current_version: event.version,
          events_processed: replay.events_processed + 1
      }

      {{:ok, transformed}, updated}
    rescue
      e ->
        updated = %{
          replay
          | errors: [%{event: event.id, error: inspect(e)} | replay.errors]
        }

        {{:error, e}, updated}
    end
  end

  defp calculate_delay(config) do
    case config.mode do
      :instant -> 0
      :realtime -> 1000
      :accelerated -> round(1000 / config.speed)
      :stepped -> 0
    end
  end
end
