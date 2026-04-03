defmodule Indrajaal.Substrate.L7.MigrationPattern do
  @moduledoc """
  ## Design Intent
  L7 substrate Migration Pattern — pure functional population movement tracker.
  Tracks the movement of entities (agents, workloads, data) across ecosystem
  zones. Computes flow balance, migration pressure, and hotspot detection
  using a population flux model.

  Flux model:
    flux(zone_a → zone_b) = Σ migrations with that route
    net_flow(zone) = inbound_flux − outbound_flux

  Pressure index (attraction/repulsion):
    pressure = net_flow / max(total_capacity, 1)

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED (L7)
  - SC-ECO-005: Ecosystem service boundaries — ENFORCED
  - SC-DIST-001: Distribution — distributed mesh patterns — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @max_zones 64
  @max_events 1024

  @type zone_id :: String.t()

  @type migration_event :: %{
          id: String.t(),
          from_zone: zone_id(),
          to_zone: zone_id(),
          entity_count: pos_integer(),
          entity_type: atom(),
          tick: non_neg_integer()
        }

  @type zone_stats :: %{
          capacity: pos_integer(),
          current_population: non_neg_integer(),
          inbound: non_neg_integer(),
          outbound: non_neg_integer(),
          net_flow: integer(),
          pressure: float()
        }

  @type t :: %__MODULE__{
          zones: %{zone_id() => zone_stats()},
          events: [migration_event()],
          tick: non_neg_integer()
        }

  defstruct zones: %{},
            events: [],
            tick: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    zone_specs = Keyword.get(opts, :zones, [])

    cond do
      length(zone_specs) > @max_zones ->
        {:error, "zones exceeds max #{@max_zones}"}

      true ->
        zones =
          Map.new(zone_specs, fn spec ->
            id = Map.get(spec, :id, "zone_#{:erlang.unique_integer([:positive])}")
            capacity = Map.get(spec, :capacity, 100) |> max(1)
            pop = Map.get(spec, :population, 0) |> max(0)

            {id,
             %{
               capacity: capacity,
               current_population: min(pop, capacity),
               inbound: 0,
               outbound: 0,
               net_flow: 0,
               pressure: 0.0
             }}
          end)

        {:ok, %__MODULE__{zones: zones}}
    end
  end

  @doc """
  Record a migration of `count` entities from one zone to another.
  Auto-registers zones if not present.
  """
  @spec record_migration(t(), zone_id(), zone_id(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def record_migration(%__MODULE__{} = state, from_zone, to_zone, opts \\ [])
      when is_binary(from_zone) and is_binary(to_zone) do
    cond do
      from_zone == to_zone ->
        {:error, "from_zone and to_zone must differ"}

      length(state.events) >= @max_events ->
        {:error, "event log capacity #{@max_events} reached"}

      true ->
        count = Keyword.get(opts, :count, 1) |> max(1)
        entity_type = Keyword.get(opts, :entity_type, :generic)
        id = :crypto.strong_rand_bytes(5) |> Base.encode16(case: :lower)

        event = %{
          id: id,
          from_zone: from_zone,
          to_zone: to_zone,
          entity_count: count,
          entity_type: entity_type,
          tick: state.tick
        }

        zones =
          state.zones
          |> ensure_zone(from_zone)
          |> ensure_zone(to_zone)
          |> update_in([from_zone, :outbound], &(&1 + count))
          |> update_in([from_zone, :current_population], &max(&1 - count, 0))
          |> update_in([to_zone, :inbound], &(&1 + count))
          |> update_in([to_zone, :current_population], fn p ->
            cap = get_in(state.zones, [to_zone, :capacity]) || 100
            min(p + count, cap)
          end)
          |> recompute_pressure()

        {:ok, %{state | zones: zones, events: [event | state.events]}}
    end
  end

  @doc """
  Return zones sorted by pressure (most attractive first).
  """
  @spec hotspots(t()) :: [%{zone: zone_id(), pressure: float()}]
  def hotspots(%__MODULE__{} = state) do
    state.zones
    |> Enum.map(fn {id, stats} -> %{zone: id, pressure: stats.pressure} end)
    |> Enum.sort_by(& &1.pressure, :desc)
  end

  @doc """
  Advance tick counter (used externally to timestamp new events).
  """
  @spec advance_tick(t()) :: t()
  def advance_tick(%__MODULE__{} = state), do: %{state | tick: state.tick + 1}

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    total_pop = state.zones |> Enum.reduce(0, fn {_, z}, acc -> acc + z.current_population end)
    total_events = length(state.events)

    %{
      zone_count: map_size(state.zones),
      total_population: total_pop,
      total_events: total_events,
      tick: state.tick,
      hotspot:
        state.zones
        |> Enum.max_by(fn {_, z} -> z.pressure end, fn -> {"none", %{pressure: 0.0}} end)
        |> elem(0)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp ensure_zone(zones, id) do
    Map.put_new(zones, id, %{
      capacity: 100,
      current_population: 0,
      inbound: 0,
      outbound: 0,
      net_flow: 0,
      pressure: 0.0
    })
  end

  defp recompute_pressure(zones) do
    Map.new(zones, fn {id, stats} ->
      net = stats.inbound - stats.outbound
      pressure = Float.round(net / max(stats.capacity, 1), 4)
      {id, %{stats | net_flow: net, pressure: pressure}}
    end)
  end
end
