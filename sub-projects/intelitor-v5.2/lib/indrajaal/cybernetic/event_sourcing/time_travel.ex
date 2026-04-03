defmodule Indrajaal.Cybernetic.EventSourcing.TimeTravel do
  @moduledoc """
  Time Travel - Temporal Navigation for v20.0.0

  Implements bi-temporal capabilities for event sourcing:
  - Point-in-time state reconstruction
  - Event stream navigation
  - Temporal queries across streams
  - Causality-aware time travel

  ## Temporal Model

  State(t) = fold(events[0..t], initial_state, reducer)

  Where:
  - t = Target timestamp (HLC or version)
  - events[0..t] = Events up to time t
  - reducer = State transition function

  ## Navigation Types
  - **Version-based**: Navigate to specific event version
  - **Time-based**: Navigate to HLC timestamp
  - **Causal**: Navigate following causal dependencies

  ## STAMP Constraints
  - SC-TT-001: Time travel MUST be deterministic
  - SC-TT-002: State reconstruction MUST be idempotent
  - SC-TT-003: Causality MUST be preserved
  - SC-TT-004: Future state access MUST be prohibited
  """

  require Logger

  alias Indrajaal.Cybernetic.EventSourcing.EventStore

  @type time_point ::
          {:version, non_neg_integer()} | {:hlc, non_neg_integer()} | {:datetime, DateTime.t()}
  @type navigation_result :: {:ok, map()} | {:error, term()}

  @type time_travel_state :: %{
          stream: String.t(),
          current_version: non_neg_integer(),
          current_hlc: non_neg_integer(),
          state: map(),
          reducer: function()
        }

  @doc """
  Creates a time travel navigator for a stream.
  """
  @spec new(String.t(), map(), function()) :: time_travel_state()
  def new(stream, initial_state \\ %{}, reducer \\ &default_reducer/2) do
    %{
      stream: stream,
      current_version: 0,
      current_hlc: 0,
      state: initial_state,
      reducer: reducer
    }
  end

  @doc """
  Navigates to a specific point in time.
  """
  @spec goto(time_travel_state(), time_point()) :: navigation_result()
  def goto(tt_state, time_point) do
    case time_point do
      {:version, version} ->
        goto_version(tt_state, version)

      {:hlc, hlc} ->
        goto_hlc(tt_state, hlc)

      {:datetime, dt} ->
        goto_datetime(tt_state, dt)
    end
  end

  @doc """
  Navigates to a specific version.
  """
  @spec goto_version(time_travel_state(), non_neg_integer()) :: navigation_result()
  def goto_version(tt_state, target_version) do
    current = tt_state.current_version

    cond do
      target_version == current ->
        {:ok, tt_state}

      target_version > current ->
        # Move forward
        forward_to_version(tt_state, target_version)

      target_version < current ->
        # Must rebuild from scratch (SC-TT-002: idempotent)
        rebuild_to_version(tt_state, target_version)
    end
  end

  @doc """
  Navigates to a specific HLC timestamp.
  """
  @spec goto_hlc(time_travel_state(), non_neg_integer()) :: navigation_result()
  def goto_hlc(tt_state, target_hlc) do
    # Find version corresponding to HLC
    case find_version_for_hlc(tt_state.stream, target_hlc) do
      {:ok, version} ->
        goto_version(tt_state, version)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Navigates to a specific datetime.
  """
  @spec goto_datetime(time_travel_state(), DateTime.t()) :: navigation_result()
  def goto_datetime(tt_state, target_dt) do
    # Convert datetime to HLC approximation
    target_hlc = DateTime.to_unix(target_dt, :nanosecond)
    goto_hlc(tt_state, target_hlc)
  end

  @doc """
  Gets the state at a specific point without modifying navigator.
  """
  @spec peek(time_travel_state(), time_point()) :: {:ok, map()} | {:error, term()}
  def peek(tt_state, time_point) do
    # Create temporary navigator
    case goto(tt_state, time_point) do
      {:ok, temp_state} ->
        {:ok, temp_state.state}

      error ->
        error
    end
  end

  @doc """
  Gets states at multiple points (efficient batch query).
  """
  @spec multi_peek(time_travel_state(), [time_point()]) :: [{time_point(), map()}]
  def multi_peek(tt_state, time_points) do
    # Sort by version for efficient forward traversal
    sorted =
      time_points
      |> Enum.map(fn tp -> {tp, resolve_to_version(tt_state.stream, tp)} end)
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.sort_by(fn {_, v} -> v end)

    # Traverse once, collecting states
    {results, _} =
      Enum.reduce(sorted, {[], tt_state}, fn {tp, _}, {acc, current} ->
        case goto(current, tp) do
          {:ok, new_state} ->
            {[{tp, new_state.state} | acc], new_state}

          _ ->
            {acc, current}
        end
      end)

    Enum.reverse(results)
  end

  @doc """
  Gets the difference between two time points.
  """
  @spec diff(time_travel_state(), time_point(), time_point()) :: {:ok, [map()]} | {:error, term()}
  def diff(tt_state, from_point, to_point) do
    from_version = resolve_to_version(tt_state.stream, from_point) || 0
    to_version = resolve_to_version(tt_state.stream, to_point)

    if to_version == nil do
      {:error, :invalid_time_point}
    else
      case EventStore.read(tt_state.stream, from_version: from_version, to_version: to_version) do
        {:ok, events} ->
          {:ok, events}

        error ->
          error
      end
    end
  end

  @doc """
  Follows causal dependencies to reconstruct causally-consistent state.
  """
  @spec follow_causality(time_travel_state(), map()) :: {:ok, map()} | {:error, term()}
  def follow_causality(tt_state, target_event) do
    # Get causal dependencies
    deps = Map.get(target_event, :causal_deps, %{})

    # Reconstruct state including all causal predecessors
    all_events = collect_causal_events(tt_state.stream, target_event, deps)

    # Apply events in causal order
    final_state =
      all_events
      |> sort_by_causality()
      |> Enum.reduce(tt_state.state, tt_state.reducer)

    {:ok, final_state}
  end

  @doc """
  Returns summary of time travel state.
  """
  @spec summary(time_travel_state()) :: map()
  def summary(tt_state) do
    %{
      stream: tt_state.stream,
      current_version: tt_state.current_version,
      current_hlc: tt_state.current_hlc,
      state_keys: Map.keys(tt_state.state)
    }
  end

  # Private helpers

  defp forward_to_version(tt_state, target_version) do
    case EventStore.read(tt_state.stream,
           from_version: tt_state.current_version,
           to_version: target_version
         ) do
      {:ok, events} ->
        # Apply events
        {new_state, last_hlc} =
          Enum.reduce(events, {tt_state.state, tt_state.current_hlc}, fn event, {state, _hlc} ->
            {tt_state.reducer.(state, event), event.hlc_timestamp}
          end)

        {:ok,
         %{
           tt_state
           | state: new_state,
             current_version: target_version,
             current_hlc: last_hlc
         }}

      error ->
        error
    end
  end

  defp rebuild_to_version(tt_state, target_version) do
    # Rebuild from scratch for consistency (SC-TT-001: deterministic)
    case EventStore.read(tt_state.stream, to_version: target_version) do
      {:ok, events} ->
        initial_state = %{}

        {new_state, last_hlc} =
          Enum.reduce(events, {initial_state, 0}, fn event, {state, _hlc} ->
            {tt_state.reducer.(state, event), event.hlc_timestamp}
          end)

        {:ok,
         %{
           tt_state
           | state: new_state,
             current_version: target_version,
             current_hlc: last_hlc
         }}

      error ->
        error
    end
  end

  defp find_version_for_hlc(stream, target_hlc) do
    case EventStore.read(stream) do
      {:ok, events} ->
        # Find event with HLC <= target_hlc
        matching =
          events
          |> Enum.filter(fn e -> e.hlc_timestamp <= target_hlc end)
          |> List.last()

        if matching do
          {:ok, matching.version}
        else
          {:ok, 0}
        end

      error ->
        error
    end
  end

  defp resolve_to_version(stream, time_point) do
    case time_point do
      {:version, v} ->
        v

      {:hlc, hlc} ->
        case find_version_for_hlc(stream, hlc) do
          {:ok, v} -> v
          _ -> nil
        end

      {:datetime, dt} ->
        hlc = DateTime.to_unix(dt, :nanosecond)

        case find_version_for_hlc(stream, hlc) do
          {:ok, v} -> v
          _ -> nil
        end
    end
  end

  defp collect_causal_events(stream, event, _deps) do
    # Simplified: just get all events up to this one
    case EventStore.read(stream, to_version: event.version) do
      {:ok, events} -> events
      _ -> [event]
    end
  end

  defp sort_by_causality(events) do
    # Sort by HLC for causal ordering
    Enum.sort_by(events, & &1.hlc_timestamp)
  end

  defp default_reducer(state, event) do
    # Default: merge event data into state
    Map.merge(state, event.data)
  end
end
